set -euo pipefail

# core/config.lua
cat > lua/gitwiz/core/config.lua <<'FILE'
-- core/config.lua
local M = {}
local defaults = {
  commits = {
    limit = 3000, -- default listing limit
  },
  runner = {
    timeout = 10000, -- ms (reserved for async future)
  },
}
local state = vim.deepcopy(defaults)

function M.setup(opts)
  if opts then
    state = vim.tbl_deep_extend("force", state, opts)
  end
end

function M.get()
  return state
end

return M
FILE

# core/events.lua
cat > lua/gitwiz/core/events.lua <<'FILE'
-- core/events.lua
local log = require("gitwiz.log")
local M = { _subs = {} }

function M.on(name, cb)
  if type(cb) ~= "function" then
    return function() end
  end
  if not M._subs[name] then
    M._subs[name] = {}
  end
  table.insert(M._subs[name], cb)
  return function()
    local list = M._subs[name]
    if not list then return end
    for i, fn in ipairs(list) do
      if fn == cb then
        table.remove(list, i)
        break
      end
    end
  end
end

function M.emit(name, payload)
  local list = M._subs[name]
  if not list then return end
  for _, cb in ipairs(list) do
    local ok, err = pcall(cb, payload)
    if not ok then
      log.warn("Event handler error: " .. tostring(err))
    end
  end
end

return M
FILE

# core/runner.lua
cat > lua/gitwiz/core/runner.lua <<'FILE'
-- core/runner.lua
local log = require("gitwiz.log")
local config = require("gitwiz.core.config")

local M = {}
local metrics = { git_calls = 0 }

local function split_lines(s)
  local t = {}
  for line in (s or ""):gmatch("[^\r\n]+") do
    t[#t+1] = line
  end
  return t
end

function M.run(args, opts)
  -- Synchronous implementation (will be upgraded to async later)
  metrics.git_calls = metrics.git_calls + 1
  local cmd = { "git" }
  vim.list_extend(cmd, args)
  local start = vim.loop.hrtime()
  local out = vim.fn.system(cmd)
  local code = vim.v.shell_error
  local duration = (vim.loop.hrtime() - start) / 1e6
  local ok = code == 0
  if not ok then
    log.debug("git failed: " .. table.concat(cmd, " ") .. " exit=" .. code)
  end
  return {
    ok = ok,
    code = code,
    cmd = cmd,
    stdout = out,
    stderr = ok and "" or out,
    stdout_lines = split_lines(out),
    duration_ms = duration,
    opts = opts,
  }
end

function M.metrics()
  return vim.deepcopy(metrics)
end

return M
FILE

# domain/commits.lua
cat > lua/gitwiz/domain/commits.lua <<'FILE'
-- domain/commits.lua
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")

local M = {}
local cache = {
  current_set = nil,
  last_all = nil,
}

local function build_current_set()
  local r = runner.run({ "log", "--pretty=%H" })
  if not r.ok then
    return {}
  end
  local set = {}
  for _, h in ipairs(r.stdout_lines) do
    set[h] = true
  end
  return set
end

local function parse_line(line)
  -- Format: %h%x1f%an%x1f%ad%x1f%s
  -- %x1f is ASCII unit separator
  local parts = {}
  for field in line:gmatch("([^\31]+)") do
    parts[#parts+1] = field
  end
  local hash = parts[1]
  local author = parts[2]
  local date = parts[3]
  local subject = parts[4]
  if not hash then
    return nil
  end
  return {
    hash = hash,
    author = author or "",
    date = date or "",
    subject = subject or "",
    in_current = false, -- filled after current_set ready
  }
end

function M.list(opts)
  opts = opts or {}
  local cfg = config.get()
  local limit = opts.limit or cfg.commits.limit
  local r = runner.run({ "log", "--all", "--date=short", "--pretty=%h%x1f%an%x1f%ad%x1f%s" })
  if not r.ok then
    return {
      ok = false,
      error = { reason = "git_error", message = "git log failed", details = r.stderr },
    }
  end

  cache.current_set = build_current_set()

  local items = {}
  for _, line in ipairs(r.stdout_lines) do
    if line ~= "" then
      local parsed = parse_line(line)
      if parsed then
        parsed.in_current = cache.current_set[parsed.hash] or false
        items[#items+1] = parsed
      end
    end
  end
  cache.last_all = items
  if limit and #items > limit then
    local sliced = {}
    for i = 1, limit do
      sliced[i] = items[i]
    end
    items = sliced
  end
  return { ok = true, data = items }
end

-- Future: function M.invalidate() end (after actions that change commits)

return M
FILE

# actions/commits.lua
cat > lua/gitwiz/actions/commits.lua <<'FILE'
-- actions/commits.lua
local runner = require("gitwiz.core.runner")
local events = require("gitwiz.core.events")
local log = require("gitwiz.log")

local M = {}

local function list_conflicts()
  local r = runner.run({ "diff", "--name-only", "--diff-filter=U" })
  if not r.ok then
    return {}
  end
  return r.stdout_lines
end

function M.cherry_pick(hash)
  if not hash or hash == "" then
    return { ok = false, error = { reason = "invalid_arg", message = "Empty hash" } }
  end
  events.emit("cherry_pick:start", { hash = hash })
  local r = runner.run({ "cherry-pick", hash })
  if r.ok then
    log.info("Cherry-pick success: " .. hash)
    events.emit("cherry_pick:success", { hash = hash })
    events.emit("cherry_pick:done", { applied = { hash } })
    return { ok = true, data = { applied = { hash } } }
  end
  local conflicts = list_conflicts()
  if #conflicts > 0 then
    log.warn("Conflicts during cherry-pick: " .. hash)
    events.emit("cherry_pick:conflict", { hash = hash, conflicts = conflicts })
    return {
      ok = false,
      error = { reason = "conflicts", message = "Conflicts detected", details = conflicts },
    }
  end
  events.emit("cherry_pick:error", { hash = hash, stderr = r.stderr })
  return {
    ok = false,
    error = { reason = "git_error", message = "Cherry-pick failed", details = r.stderr },
  }
end

function M.cherry_pick_many(hashes)
  if not hashes or #hashes == 0 then
    return { ok = false, error = { reason = "invalid_arg", message = "No hashes" } }
  end
  local applied = {}
  for i = #hashes, 1, -1 do
    local h = hashes[i]
    local res = M.cherry_pick(h)
    if not res.ok then
      return {
        ok = false,
        error = res.error,
        data = { applied = applied, last = h },
      }
    end
    table.insert(applied, h)
  end
  events.emit("cherry_pick:done", { applied = applied })
  return { ok = true, data = { applied = applied } }
end

return M
FILE

# ui/telescope/commits.lua
cat > lua/gitwiz/ui/telescope/commits.lua <<'FILE'
-- ui/telescope/commits.lua
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

local domain_commits = require("gitwiz.domain.commits")
local actions_commits = require("gitwiz.actions.commits")
local events = require("gitwiz.core.events")
local log = require("gitwiz.log")

local M = {}

local function to_display(item)
  local mark = item.in_current and "✔" or "✘"
  return string.format("%-3s %-30s %-15s %-12s %-12s",
    mark, item.subject, item.author, item.date, item.hash)
end

local function build_finder(commits)
  return finders.new_table {
    results = commits,
    entry_maker = function(entry)
      return {
        value = entry,
        display = to_display(entry),
        ordinal = table.concat({
          entry.subject, entry.author, entry.date, entry.hash,
        }, " "),
      }
    end,
  }
end

function M.open(opts)
  opts = opts or {}
  local result = domain_commits.list({ limit = opts.limit })
  if not result.ok then
    log.error("Failed to list commits: " .. (result.error and result.error.message or ""))
    return
  end
  local commits = result.data

  local picker
  picker = pickers.new({}, {
    prompt_title = "GitWiz Commits (V2)",
    finder = build_finder(commits),
    sorter = sorters.get_fzy_sorter(),
    attach_mappings = function(prompt_bufnr, map)

      local function refresh()
        local updated = domain_commits.list({ limit = opts.limit })
        if updated.ok then
          picker:refresh(build_finder(updated.data), { reset_prompt = false })
        end
      end

      local function cherry_pick_selected()
        local pk = action_state.get_current_picker(prompt_bufnr)
        local sels = pk:get_multi_selection()
        if #sels == 0 then
          sels = { action_state.get_selected_entry() }
        end
        local hashes = {}
        for _, e in ipairs(sels) do
          hashes[#hashes+1] = e.value.hash
        end
        local res
        if #hashes == 1 then
          res = actions_commits.cherry_pick(hashes[1])
        else
          res = actions_commits.cherry_pick_many(hashes)
        end
        if res.ok then
          log.info("Cherry-pick applied count=" .. #hashes)
          refresh()
        else
          if res.error.reason == "conflicts" then
            log.warn("Conflicts detected (" .. #res.error.details .. " files)")
          else
            log.error("Cherry-pick failed: " .. (res.error.message or "error"))
          end
          refresh()
        end
      end

      map("i", "<C-p>", cherry_pick_selected)
      map("n", "<C-p>", cherry_pick_selected)

      -- Auto-refresh when events fire
      events.on("cherry_pick:success", function() refresh() end)
      events.on("cherry_pick:conflict", function() refresh() end)
      events.on("cherry_pick:done", function() refresh() end)

      -- Enter: simple close (or future: show details)
      map("i", "<CR>", function() actions.close(prompt_bufnr) end)
      map("n", "<CR>", function() actions.close(prompt_bufnr) end)

      return true
    end,
  })

  picker:find()
end

return M
FILE

# api.lua
cat > lua/gitwiz/api.lua <<'FILE'
-- api.lua
local commits_domain = require("gitwiz.domain.commits")
local commits_actions = require("gitwiz.actions.commits")
local events = require("gitwiz.core.events")
local runner = require("gitwiz.core.runner")

local M = {}

M.commits = {
  list = function(opts) return commits_domain.list(opts) end,
}

M.actions = {
  commits = {
    cherry_pick = commits_actions.cherry_pick,
    cherry_pick_many = commits_actions.cherry_pick_many,
  },
}

M.events = {
  on = events.on,
}

M.metrics = function()
  return {
    runner = runner.metrics(),
  }
end

return M
FILE

# init.lua (nuevo)
cat > lua/gitwiz/init.lua <<'FILE'
-- init.lua (new core entrypoint)
local config = require("gitwiz.core.config")
local runner = require("gitwiz.core.runner")
local log = require("gitwiz.log")

local M = {}

function M.setup(opts)
  opts = opts or {}
  config.setup(opts)
  -- runner may use opts.runner later (async/timeouts)
  if opts.log and opts.log.level then
    -- Adjust log level if provided
    require("gitwiz.log").set_level(opts.log.level)
  end

  -- User command for new picker
  vim.api.nvim_create_user_command("GitWizCommitsV2", function()
    require("gitwiz.ui.telescope.commits").open({})
  end, {})

  log.info("GitWiz (V2 core) initialized")
end

return M
FILE

echo "[GitWiz] New core files created."

