-- graph/layout.lua
local M = {}

M.state = {
  tabnr = nil,
  win = {
    tree = nil,
    graph = nil,
    info = nil,
  },
  buf = {
    tree = nil,
    graph = nil,
    info = nil,
  },
}

local function create_buf(name)
  local b = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(b, "GitWizGraph:" .. name .. ":" .. b)
  return b
end

local function set_title(win, title)
  if win and vim.api.nvim_win_is_valid(win) then
    pcall(vim.api.nvim_set_option_value, "winbar", title, { scope = "local", win = win })
  end
end

function M.ensure()
  if M.state.tabnr and vim.api.nvim_tabpage_is_valid(M.state.tabnr) then
    vim.api.nvim_set_current_tabpage(M.state.tabnr)
    return
  end
  vim.cmd("tabnew")
  M.state.tabnr = vim.api.nvim_get_current_tabpage()

  local main = vim.api.nvim_get_current_win()
  -- vertical split for graph
  vim.cmd("vsplit")
  local right = vim.api.nvim_get_current_win()
  local left = main
  vim.api.nvim_win_set_width(left, 32)

  -- split bottom on right for info
  vim.api.nvim_set_current_win(right)
  vim.cmd("split")
  local bottom = vim.api.nvim_get_current_win()
  local top = vim.fn.win_getid(vim.fn.winnr("k"))

  M.state.win.tree = left
  M.state.win.graph = top
  M.state.win.info = bottom

  M.state.buf.tree = create_buf("tree")
  M.state.buf.graph = create_buf("graph")
  M.state.buf.info = create_buf("info")

  vim.api.nvim_win_set_buf(M.state.win.tree, M.state.buf.tree)
  vim.api.nvim_win_set_buf(M.state.win.graph, M.state.buf.graph)
  vim.api.nvim_win_set_buf(M.state.win.info, M.state.buf.info)

  set_title(M.state.win.tree, " Branches ")
  set_title(M.state.win.graph, " Graph ")
  set_title(M.state.win.info, " Details ")

  for _, b in pairs(M.state.buf) do
    vim.api.nvim_buf_set_option(b, "bufhidden", "wipe")
  end
end

function M.close()
  if M.state.tabnr and vim.api.nvim_tabpage_is_valid(M.state.tabnr) then
    vim.cmd("tabclose")
  end
  M.state = {
    tabnr = nil,
    win = { tree = nil, graph = nil, info = nil },
    buf = { tree = nil, graph = nil, info = nil },
  }
end

return M

