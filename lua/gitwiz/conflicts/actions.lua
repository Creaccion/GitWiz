-- conflicts/actions.lua (add keep_both + clean_markers)
local manager = require("gitwiz.conflicts.manager")
local runner = require("gitwiz.core.runner")
local log = require("gitwiz.log")
local events = require("gitwiz.core.events")
local config = require("gitwiz.core.config")
local parser = require("gitwiz.conflicts.parser")

local M = {}

local function git_ok(cmd)
  return runner.run(cmd)
end

function M.pick_stage(path, stage)
  local lines = manager.load_stage(path, stage)
  if not lines then
    return { ok = false, error = "stage_unavailable" }
  end
  manager.write_working(path, lines)
  return { ok = true }
end

function M.pick_ours(path)
  return M.pick_stage(path, 2)
end

function M.pick_theirs(path)
  return M.pick_stage(path, 3)
end

function M.pick_base(path)
  return M.pick_stage(path, 1)
end

-- Keep both versions (OURS then THEIRS) separated by config separator
function M.keep_both(path)
  local cfg = config.get()
  local sep = cfg.conflicts.keep_both_separator or "====== OURS / THEIRS ======"
  local lines = manager.load_working(path)
  local new_lines, count = parser.keep_both_transform(lines, sep)
  if count == 0 then
    return { ok = false, error = "no_blocks" }
  end
  manager.write_working(path, new_lines)
  return { ok = true, blocks = count }
end

-- Remove conflict markers only (clean)
function M.clean_markers(path)
  local lines = manager.load_working(path)
  local new_lines, removed = parser.clean_markers(lines)
  if removed == 0 then
    return { ok = false, error = "no_markers" }
  end
  manager.write_working(path, new_lines)
  return { ok = true, removed = removed }
end

function M.mark_resolved(path)
  local r = git_ok({ "add", path })
  if not r.ok then
    return { ok = false, error = r.stderr }
  end
  manager.mark_resolved(path)
  return { ok = true }
end

function M.unmark(path)
  local r = git_ok({ "reset", "HEAD", path })
  if not r.ok then
    return { ok = false, error = r.stderr }
  end
  return { ok = true }
end

function M.continue_pick()
  local r = git_ok({ "cherry-pick", "--continue" })
  if r.ok then
    events.emit("cherry_pick:continue", {})
    return { ok = true }
  end
  return { ok = false, error = r.stderr }
end

function M.abort_pick()
  local r = git_ok({ "cherry-pick", "--abort" })
  if r.ok then
    events.emit("cherry_pick:abort", {})
    return { ok = true }
  end
  return { ok = false, error = r.stderr }
end

function M.skip_pick()
  local r = git_ok({ "cherry-pick", "--skip" })
  if r.ok then
    events.emit("cherry_pick:skip", {})
    return { ok = true }
  end
  return { ok = false, error = r.stderr }
end

function M.reload_conflicts()
  manager.refresh()
  return manager.state.files
end

function M.auto_finish_if_needed(close_fn)
  manager.refresh()
  if manager.has_conflicts() then
    return
  end
  if not manager.in_cherry_pick() then
    if config.get().conflicts.auto_close and close_fn then close_fn() end
    return
  end
  local choice = vim.fn.confirm(
    "No conflicts remain. Continue cherry-pick?",
    "&Continue\n&Abort\n&Skip\n&Do Nothing",
    1
  )
  if choice == 1 then
    local r = M.continue_pick()
    if not r.ok then
      log.warn("Continue failed: " .. (r.error or ""))
      return
    end
  elseif choice == 2 then
    M.abort_pick()
  elseif choice == 3 then
    M.skip_pick()
  else
    return
  end
  if config.get().conflicts.auto_close and close_fn then close_fn() end
end

return M
