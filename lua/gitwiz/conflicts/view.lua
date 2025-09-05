-- conflicts/view.lua (close-all mapping + title refresh on load)
local manager = require("gitwiz.conflicts.manager")
local layout = require("gitwiz.conflicts.layout")
local actions = require("gitwiz.conflicts.actions")
local config = require("gitwiz.core.config")
local log = require("gitwiz.log")

local M = {}

local function set_lines(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
end

local function set_working(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(buf, "modifiable", true)
end

function M.load_current()
  local cur = manager.current()
  layout.update_titles()
  if not cur then
    set_lines(layout.buf.working, { "No conflicts." })
    set_lines(layout.buf.ours, {})
    set_lines(layout.buf.theirs, {})
    return
  end
  local path = cur.path
  local working = manager.load_working(path)
  local ours = manager.load_stage(path, 2) or { "[no stage 2]" }
  local theirs = manager.load_stage(path, 3) or { "[no stage 3]" }

  set_working(layout.buf.working, working)
  set_lines(layout.buf.ours, ours)
  set_lines(layout.buf.theirs, theirs)

  vim.api.nvim_buf_set_var(layout.buf.working, "gitwiz_conflict_path", path)
end

local function get_current_path()
  if not layout.buf.working or not vim.api.nvim_buf_is_valid(layout.buf.working) then
    return nil
  end
  local ok, val = pcall(vim.api.nvim_buf_get_var, layout.buf.working, "gitwiz_conflict_path")
  if not ok then return nil end
  return val
end

local function with_path(cb)
  local path = get_current_path()
  if not path then
    log.warn("No file selected")
    return
  end
  cb(path)
end

function M.setup_working_keymaps()
  local km = config.get().conflicts.keymaps.working
  local buf = layout.buf.working
  if not buf then return end
  local function map(lhs, fn)
    vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true })
  end

  map(km.pick_ours, function()
    with_path(function(p)
      if actions.pick_ours(p).ok then M.load_current() end
    end)
  end)

  map(km.pick_theirs, function()
    with_path(function(p)
      if actions.pick_theirs(p).ok then M.load_current() end
    end)
  end)

  map(km.pick_base, function()
    with_path(function(p)
      if actions.pick_base(p).ok then M.load_current() end
    end)
  end)

  map(km.keep_both, function()
    with_path(function(p)
      local r = actions.keep_both(p)
      if not r.ok then
        log.warn("Keep both failed (no conflict blocks?)")
        return
      end
      log.info("Merged both sides (" .. r.blocks .. " block(s))")
      M.load_current()
    end)
  end)

  map(km.clean_markers, function()
    with_path(function(p)
      local r = actions.clean_markers(p)
      if not r.ok then
        log.warn("No markers to clean")
        return
      end
      log.info("Removed " .. r.removed .. " marker lines")
      M.load_current()
    end)
  end)

  map(km.mark_resolved, function()
    with_path(function(p)
      local ok = actions.mark_resolved(p).ok
      if not ok then
        log.warn("Mark resolved failed")
        return
      end
      actions.auto_finish_if_needed(require("gitwiz.conflicts").close)
      M.load_current()
      require("gitwiz.conflicts.tree").refresh()
    end)
  end)

  map(km.continue_pick, function()
    local r = actions.continue_pick()
    if not r.ok then log.warn("Continue failed") end
    actions.auto_finish_if_needed(require("gitwiz.conflicts").close)
  end)

  map(km.abort_pick, function()
    if vim.fn.confirm("Abort cherry-pick?", "&Yes\n&No", 2) ~= 1 then return end
    local r = actions.abort_pick()
    if not r.ok then log.warn("Abort failed") end
    actions.auto_finish_if_needed(require("gitwiz.conflicts").close)
  end)

  map(km.skip_pick, function()
    local r = actions.skip_pick()
    if not r.ok then log.warn("Skip failed") end
    actions.auto_finish_if_needed(require("gitwiz.conflicts").close)
  end)

  map(km.next_file, function()
    manager.next()
    M.load_current()
    require("gitwiz.conflicts.tree").refresh()
  end)

  map(km.prev_file, function()
    manager.prev()
    M.load_current()
    require("gitwiz.conflicts.tree").refresh()
  end)

  -- Close entire interface from working buffer
  map(km.close_all, function()
    if manager.has_conflicts() then
      if vim.fn.confirm("Close conflict panel? Conflicts remain.", "&Yes\n&No", 2) ~= 1 then
        return
      end
    end
    require("gitwiz.conflicts").close()
  end)

  -- Override plain 'q' to close all instead of only moving back (requested)
  map("q", function()
    if manager.has_conflicts() then
      if vim.fn.confirm("Close conflict panel? Conflicts remain.", "&Yes\n&No", 2) ~= 1 then
        return
      end
    end
    require("gitwiz.conflicts").close()
  end)

  -- Also add 'q' in ours/theirs buffers to close all
  for _, b in ipairs({ layout.buf.ours, layout.buf.theirs }) do
    if b and vim.api.nvim_buf_is_valid(b) then
      vim.keymap.set("n", "q", function()
        if manager.has_conflicts() then
          if vim.fn.confirm("Close conflict panel? Conflicts remain.", "&Yes\n&No", 2) ~= 1 then
            return
          end
        end
        require("gitwiz.conflicts").close()
      end, { buffer = b, nowait = true, silent = true })
    end
  end
end

return M
