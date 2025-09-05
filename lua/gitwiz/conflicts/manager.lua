-- conflicts/manager.lua (add metadata about current operation and commits)
local runner = require("gitwiz.core.runner")
local log = require("gitwiz.log")

local M = {
  state = {
    files = {},
    index = 1,
    open = false,
    meta = nil, -- { operation="cherry-pick"/"revert"/nil, branch, head_full, head_short, theirs_full, theirs_short, theirs_author, theirs_subject }
  },
}

local function run_git(args)
  return runner.run(args)
end

local function list_conflicts()
  local r = run_git({ "diff", "--name-only", "--diff-filter=U" })
  if not r.ok then
    return {}
  end
  local t = {}
  for _, line in ipairs(r.stdout_lines) do
    if line ~= "" then
      local has_base = false
      local probe = run_git({ "show", (":1:" .. line) })
      if probe.ok and probe.stdout ~= "" then
        has_base = true
      end
      table.insert(t, { path = line, has_base = has_base, resolved = false })
    end
  end
  return t
end

local function index_by_path(path)
  for i, f in ipairs(M.state.files) do
    if f.path == path then
      return i
    end
  end
end

-- Gather metadata about current cherry-pick / revert
local function collect_meta()
  local meta = {
    operation = nil,
    branch = nil,
    head_full = nil,
    head_short = nil,
    theirs_full = nil,
    theirs_short = nil,
    theirs_author = nil,
    theirs_subject = nil,
  }

  local cp = vim.loop.fs_stat(".git/CHERRY_PICK_HEAD")
  local rv = vim.loop.fs_stat(".git/REVERT_HEAD")

  if cp then
    meta.operation = "cherry-pick"
    local ok, head = pcall(vim.fn.readfile, ".git/CHERRY_PICK_HEAD")
    if ok and head[1] then
      meta.theirs_full = head[1]:gsub("%s+", "")
    end
  elseif rv then
    meta.operation = "revert"
    local ok, head = pcall(vim.fn.readfile, ".git/REVERT_HEAD")
    if ok and head[1] then
      meta.theirs_full = head[1]:gsub("%s+", "")
    end
  end

  -- Branch & HEAD
  local b = run_git({ "rev-parse", "--abbrev-ref", "HEAD" })
  if b.ok then
    meta.branch = (b.stdout_lines[1] or "HEAD")
  end
  local head_full = run_git({ "rev-parse", "HEAD" })
  if head_full.ok then
    meta.head_full = head_full.stdout_lines[1]
  end
  local head_short = run_git({ "rev-parse", "--short", "HEAD" })
  if head_short.ok then
    meta.head_short = head_short.stdout_lines[1]
  end

  if meta.theirs_full then
    local show = run_git({
      "show", "-s",
      "--pretty=format:%H%x1f%h%x1f%an%x1f%s",
      meta.theirs_full,
    })
    if show.ok and show.stdout ~= "" then
      local parts = {}
      for field in show.stdout:gmatch("([^\31]+)") do
        parts[#parts+1] = field
      end
      meta.theirs_full = parts[1] or meta.theirs_full
      meta.theirs_short = parts[2]
      meta.theirs_author = parts[3]
      meta.theirs_subject = parts[4]
    end
  end

  M.state.meta = meta
end

function M.refresh()
  local current_path = M.current_file()
  M.state.files = list_conflicts()
  collect_meta()
  if #M.state.files == 0 then
    M.state.index = 1
    return
  end
  if current_path then
    local idx = index_by_path(current_path)
    if idx then
      M.state.index = idx
    else
      if M.state.index > #M.state.files then
        M.state.index = #M.state.files
      end
    end
  else
    M.state.index = 1
  end
end

function M.has_conflicts()
  return #M.state.files > 0
end

function M.current()
  return M.state.files[M.state.index]
end

function M.current_file()
  local cur = M.current()
  return cur and cur.path or nil
end

function M.next()
  if #M.state.files == 0 then return end
  M.state.index = (M.state.index % #M.state.files) + 1
  return M.current()
end

function M.prev()
  if #M.state.files == 0 then return end
  M.state.index = (M.state.index - 2) % #M.state.files + 1
  return M.current()
end

function M.set_index(i)
  if i >= 1 and i <= #M.state.files then
    M.state.index = i
  end
end

function M.mark_resolved(path)
  for _, f in ipairs(M.state.files) do
    if f.path == path then
      f.resolved = true
      break
    end
  end
end

function M.in_cherry_pick()
  local cp = vim.loop.fs_stat(".git/CHERRY_PICK_HEAD")
  local rv = vim.loop.fs_stat(".git/REVERT_HEAD")
  return cp ~= nil or rv ~= nil
end

function M.load_stage(path, stage)
  local r = run_git({ "show", (":" .. stage .. ":" .. path) })
  if not r.ok then
    return nil
  end
  local lines = {}
  for _, l in ipairs(r.stdout_lines) do
    lines[#lines+1] = l
  end
  return lines
end

function M.load_working(path)
  local ok, content = pcall(vim.fn.readfile, path)
  if not ok then return {} end
  return content
end

function M.write_working(path, lines)
  local ok, err = pcall(vim.fn.writefile, lines, path)
  if not ok then
    log.warn("Failed to write working file: " .. tostring(err))
  end
end

function M.meta()
  return M.state.meta
end

return M
