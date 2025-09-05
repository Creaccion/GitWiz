-- domain/commits.lua (extended classification + grep content search)
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")
local primary_branch = require("gitwiz.git.primary_branch")

local M = {}

-- Build set of (limited) commits for a ref
local function rev_list_set(ref, limit)
  local args = { "rev-list" }
  if limit and tonumber(limit) then
    table.insert(args, "--max-count=" .. tostring(limit))
  end
  table.insert(args, ref)
  local r = runner.run(args)
  if not r.ok then
    return {}, false
  end
  local set = {}
  for _, h in ipairs(r.stdout_lines) do
    set[h] = true
  end
  local truncated = (limit ~= nil and #r.stdout_lines == tonumber(limit))
  return set, truncated
end

-- Parse a log line with fields:
-- %H%x1f%h%x1f%P%x1f%an%x1f%ad%x1f%ar%x1f%s
local function parse_line(line)
  local parts = {}
  for field in line:gmatch("([^\31]+)") do
    parts[#parts+1] = field
  end
  if #parts < 7 then
    return nil
  end
  local full = parts[1]
  local short = parts[2]
  local parents_raw = parts[3]
  local author = parts[4]
  local date = parts[5]
  local rel = parts[6]
  local subject = parts[7]
  local parents = {}
  if parents_raw and parents_raw ~= "" then
    for p in parents_raw:gmatch("%S+") do
      parents[#parents+1] = p
    end
  end
  return {
    hash = full,
    short = short,
    parents = parents,
    is_merge = #parents > 1,
    author = author or "",
    date = date or "",
    rel_date = rel or "",
    subject = subject or "",
    in_head = false,
    in_main = false,
    category = "foreign",
  }
end

local function classify(item, head_set, main_set)
  local in_head = head_set[item.hash] or false
  local in_main = main_set[item.hash] or false
  item.in_head = in_head
  item.in_current = in_head
  item.in_main = in_main
  if in_head and in_main then
    item.category = "common"
  elseif in_head and not in_main then
    item.category = "ahead"
  elseif in_main and not in_head then
    item.category = "behind"
  else
    item.category = "foreign"
  end
end

local function aggregate(items)
  local counts = { ahead = 0, behind = 0, foreign = 0, common = 0, total = #items }
  for _, it in ipairs(items) do
    counts[it.category] = counts[it.category] + 1
  end
  return counts
end

--- List commits with classification against HEAD and primary branch.
-- opts:
--   limit (overall log limit) default config.commits.limit
--   limits { head, main, all }
--   grep (string) pattern for git log -G (diff content regex)
function M.list(opts)
  opts = opts or {}
  local cfg = config.get()
  local limit_all = opts.limit or cfg.commits.limit or 3000

  local limits = opts.limits or {
    head = math.min(limit_all, 1500),
    main = math.min(limit_all, 2000),
    all = limit_all,
  }

  local primary = primary_branch.detect()
  local primary_name = primary.name

  local head_set, head_trunc = rev_list_set("HEAD", limits.head)
  local main_set, main_trunc = rev_list_set(primary_name, limits.main)

  local log_args = {
    "log", "--all",
    "--date=short",
    "--pretty=%H%x1f%h%x1f%P%x1f%an%x1f%ad%x1f%ar%x1f%s",
    "-n", tostring(limits.all),
  }

  if opts.grep and opts.grep ~= "" then
    -- -G (regex) diff search
    table.insert(log_args, "-G" .. opts.grep)
  end

  local r = runner.run(log_args)
  if not r.ok then
    return {
      ok = false,
      error = { reason = "git_error", message = "git log failed", details = r.stderr },
    }
  end

  local items = {}
  for _, line in ipairs(r.stdout_lines) do
    if line ~= "" then
      local parsed = parse_line(line)
      if parsed then
        classify(parsed, head_set, main_set)
        items[#items+1] = parsed
      end
    end
  end

  local counts = aggregate(items)

  local meta = {
    primary_branch = {
      name = primary_name,
      source = primary.source,
    },
    counts = counts,
    limits = limits,
    truncated = {
      head = head_trunc,
      main = main_trunc,
      all = (#items == limits.all),
    },
  }

  if opts.grep and opts.grep ~= "" then
    meta.search = {
      pattern = opts.grep,
      type = "diff_regex",
    }
  end

  return {
    ok = true,
    data = items,
    meta = meta,
  }
end

return M
