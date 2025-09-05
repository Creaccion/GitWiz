-- conflicts/layout.lua (dynamic titles with commit meta)
local manager = require("gitwiz.conflicts.manager")

local M = {
  win = {
    tree = nil,
    working = nil,
    ours = nil,
    theirs = nil,
  },
  buf = {
    tree = nil,
    working = nil,
    ours = nil,
    theirs = nil,
  },
  tabnr = nil,
}

local function create_buffer(name)
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, ("GitWizConflicts:" .. name .. ":" .. tostring(buf)))
  return buf
end

local function set_title(win, title)
  pcall(vim.api.nvim_set_option_value, "winbar", title, { scope = "local", win = win })
end

function M.update_titles()
  local mt = manager.meta() or {}
  local branch = mt.branch or "?"
  local theirs = (mt.theirs_short and mt.theirs_author) and (mt.theirs_short .. " " .. mt.theirs_author) or (mt.theirs_short or "")
  if M.win.working and vim.api.nvim_win_is_valid(M.win.working) then
    set_title(M.win.working, " WORKING (" .. branch .. ") ")
  end
  if M.win.ours and vim.api.nvim_win_is_valid(M.win.ours) then
    set_title(M.win.ours, " OURS (" .. branch .. ") ")
  end
  if M.win.theirs and vim.api.nvim_win_is_valid(M.win.theirs) then
    local label = " THEIRS "
    if theirs ~= "" then
      label = label .. "(" .. theirs .. ") "
    end
    set_title(M.win.theirs, label)
  end
end

function M.open_tab()
  if M.tabnr and vim.api.nvim_tabpage_is_valid(M.tabnr) then
    vim.api.nvim_set_current_tabpage(M.tabnr)
    return
  end
  vim.cmd("tabnew")
  M.tabnr = vim.api.nvim_get_current_tabpage()

  local main_win = vim.api.nvim_get_current_win()
  vim.cmd("vsplit")
  local right = vim.api.nvim_get_current_win()
  local left = main_win

  vim.api.nvim_win_set_width(left, 30)
  M.win.tree = left

  M.win.working = right
  M.buf.tree = create_buffer("tree")
  vim.api.nvim_win_set_buf(M.win.tree, M.buf.tree)

  M.buf.working = create_buffer("working")
  vim.api.nvim_win_set_buf(M.win.working, M.buf.working)

  vim.cmd("vsplit")
  M.win.ours = vim.api.nvim_get_current_win()
  M.buf.ours = create_buffer("ours")
  vim.api.nvim_win_set_buf(M.win.ours, M.buf.ours)

  vim.cmd("vsplit")
  M.win.theirs = vim.api.nvim_get_current_win()
  M.buf.theirs = create_buffer("theirs")
  vim.api.nvim_win_set_buf(M.win.theirs, M.buf.theirs)

  set_title(M.win.tree, " Conflicts ")
  M.update_titles()

  vim.api.nvim_set_current_win(M.win.working); vim.cmd("diffthis")
  vim.api.nvim_set_current_win(M.win.ours); vim.cmd("diffthis")
  vim.api.nvim_set_current_win(M.win.theirs); vim.cmd("diffthis")
  vim.api.nvim_set_current_win(M.win.tree)

  vim.api.nvim_buf_set_option(M.buf.tree, "filetype", "gitwiz_conflicts_tree")
  vim.api.nvim_buf_set_option(M.buf.working, "filetype", "gitwiz_conflict_working")
  vim.api.nvim_buf_set_option(M.buf.ours, "filetype", "gitwiz_conflict_stage")
  vim.api.nvim_buf_set_option(M.buf.theirs, "filetype", "gitwiz_conflict_stage")

  vim.api.nvim_buf_set_option(M.buf.ours, "modifiable", false)
  vim.api.nvim_buf_set_option(M.buf.theirs, "modifiable", false)
end

function M.close()
  if M.tabnr and vim.api.nvim_tabpage_is_valid(M.tabnr) then
    vim.cmd("tabclose")
  end
  M.tabnr = nil
  M.win = { tree = nil, working = nil, ours = nil, theirs = nil }
  M.buf = { tree = nil, working = nil, ours = nil, theirs = nil }
end

return M
