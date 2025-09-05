-- conflicts/init.lua
local manager = require("gitwiz.conflicts.manager")
local layout = require("gitwiz.conflicts.layout")
local tree = require("gitwiz.conflicts.tree")
local view = require("gitwiz.conflicts.view")
local config = require("gitwiz.core.config")
local log = require("gitwiz.log")

local M = {}

function M.open()
  layout.open_tab()
  manager.refresh()
  tree.refresh()
  tree.setup_keymaps()
  view.load_current()
  view.setup_working_keymaps()
  manager.state.open = true
end

function M.close()
  layout.close()
  manager.state.open = false
end

function M.toggle()
  if manager.state.open then
    M.close()
  else
    M.open()
  end
end

-- Called on conflict events
function M.on_conflict_event()
  if not config.get().conflicts.auto_open then
    return
  end
  if not manager.state.open then
    M.open()
  else
    -- just refresh list
    manager.refresh()
    tree.refresh()
    view.load_current()
  end
end

return M

