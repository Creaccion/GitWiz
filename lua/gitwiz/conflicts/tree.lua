-- conflicts/tree.lua (meta section + improved legend + close-all q in any pane)
local manager = require("gitwiz.conflicts.manager")
local layout = require("gitwiz.conflicts.layout")
local view = require("gitwiz.conflicts.view")
local config = require("gitwiz.core.config")

local M = {}

local function build_meta_section()
  local cfg = config.get().conflicts
  if not cfg.show_meta then return {} end
  local mt = manager.meta() or {}
  local lines = {}
  if not mt.operation then
    lines[#lines+1] = "Operation: (none)"
    return lines
  end
  lines[#lines+1] = "Operation: " .. mt.operation
  if mt.theirs_short then
    lines[#lines+1] = "Theirs:    " .. mt.theirs_short ..
      (mt.theirs_author and (" (" .. mt.theirs_author .. ")") or "")
  end
  if mt.theirs_subject then
    lines[#lines+1] = "Subject:   " .. mt.theirs_subject
  end
  if mt.branch then
    lines[#lines+1] = "Branch:    " .. mt.branch ..
      (mt.head_short and (" (HEAD " .. mt.head_short .. ")") or "")
  end
  return lines
end

local function build_legend()
  local cfg = config.get().conflicts
  if not cfg.show_keymaps then
    return {}
  end
  local kt = cfg.keymaps.tree
  local kw = cfg.keymaps.working
  local function list_or(tbl)
    if type(tbl) == "table" then
      return table.concat(tbl, "/")
    end
    return tbl
  end
  local lines = {}
  lines[#lines+1] = "╭─ Keymaps ──────────────────────────────────────────────"
  lines[#lines+1] = "│ Tree:"
  lines[#lines+1] =
    "│   open: " .. list_or(kt.open) ..
    "  refresh: " .. kt.refresh ..
    "  next: " .. kt.next ..
    "  prev: " .. kt.prev ..
    "  close: " .. kt.close
  lines[#lines+1] = "│ Working:"
  lines[#lines+1] =
    "│   ours: " .. kw.pick_ours ..
    "  theirs: " .. kw.pick_theirs ..
    "  base: " .. kw.pick_base ..
    "  keep both: " .. kw.keep_both
  lines[#lines+1] =
    "│   clean markers: " .. kw.clean_markers ..
    "  mark resolved: " .. kw.mark_resolved
  lines[#lines+1] =
    "│   continue: " .. kw.continue_pick ..
    "  abort: " .. kw.abort_pick ..
    "  skip: " .. kw.skip_pick
  lines[#lines+1] =
    "│   next file: " .. kw.next_file ..
    "  prev file: " .. kw.prev_file ..
    "  back tree: " .. kw.quit_to_tree ..
    "  close all: " .. kw.close_all
  lines[#lines+1] = "╰────────────────────────────────────────────────────────"
  return lines
end

local function render()
  if not layout.buf.tree or not vim.api.nvim_buf_is_valid(layout.buf.tree) then
    return
  end
  vim.api.nvim_buf_set_option(layout.buf.tree, "modifiable", true)
  local lines = {}
  -- Meta
  local meta_lines = build_meta_section()
  for _, l in ipairs(meta_lines) do
    lines[#lines+1] = l
  end
  if #meta_lines > 0 then
    lines[#lines+1] = ""
  end
  -- Files
  local files = manager.state.files
  lines[#lines+1] = ("Conflicts (" .. #files .. ")")
  lines[#lines+1] = string.rep("-", 40)
  for i, f in ipairs(files) do
    local marker = (i == manager.state.index) and "➤" or " "
    local status = f.resolved and "[R]" or "[U]"
    lines[#lines+1] = string.format("%s %s %s", marker, status, f.path)
  end
  lines[#lines+1] = ""
  -- Legend
  local legend = build_legend()
  for _, l in ipairs(legend) do
    lines[#lines+1] = l
  end
  vim.api.nvim_buf_set_lines(layout.buf.tree, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(layout.buf.tree, "modifiable", false)
end

function M.refresh()
  manager.refresh()
  layout.update_titles()
  render()
end

function M.open_file(idx)
  manager.set_index(idx)
  render()
  view.load_current()
end

local function line_to_index(l)
  -- meta section variable length: find "Conflicts (" line
  local buf_lines = vim.api.nvim_buf_get_lines(layout.buf.tree, 0, -1, false)
  local conflicts_line = nil
  for i, line in ipairs(buf_lines) do
    if line:match("^Conflicts %(") then
      conflicts_line = i
      break
    end
  end
  if not conflicts_line then return nil end
  -- first file line is conflicts_line + 2
  local offset = conflicts_line + 2
  if l < offset then return nil end
  local idx = l - offset + 1
  if idx < 1 or idx > #manager.state.files then return nil end
  return idx
end

function M.setup_keymaps()
  local km = config.get().conflicts.keymaps.tree
  local buf = layout.buf.tree
  if not buf then return end
  local function map(lhs, rhs)
    vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true })
  end
  for _, k in ipairs(km.open) do
    map(k, function()
      local l = vim.api.nvim_win_get_cursor(layout.win.tree)[1]
      local idx = line_to_index(l)
      if idx then M.open_file(idx) end
    end)
  end
  map(km.refresh, function() M.refresh() end)
  map(km.close, function()
    if manager.has_conflicts() then
      if vim.fn.confirm("Close conflict panel? Conflicts remain.", "&Yes\n&No", 2) ~= 1 then
        return
      end
    end
    require("gitwiz.conflicts").close()
  end)
  map(km.next, function()
    manager.next()
    render()
    view.load_current()
  end)
  map(km.prev, function()
    manager.prev()
    render()
    view.load_current()
  end)
end

return M
