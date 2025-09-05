-- graph/init.lua (add view mode actions gV, matrix & compact keymaps)
local layout = require("gitwiz.graph.layout")
local render = require("gitwiz.graph.render")
local branches_domain = require("gitwiz.domain.branches")
local runner = require("gitwiz.core.runner")
local log = require("gitwiz.log")
local actions = require("gitwiz.graph.actions")
local state = require("gitwiz.graph.state")

local M = {}

local function map(buf, lhs, rhs, desc)
  vim.keymap.set("n", lhs, rhs, { buffer = buf, silent = true, nowait = true, desc = desc })
end

local function load_data()
  local res = branches_domain.list({ limit_branch_commits = 8 })
  if not res.ok then
    log.error("Graph: failed to load branches")
    return { primary="", groups={} }
  end
  return res.data
end

local function redraw(data)
  render.set_data(data.primary, data.groups)
  render.refresh_all(data)
end

local function refresh()
  redraw(load_data())
end

local function checkout_branch(name)
  local r = runner.run({ "switch", name })
  if not r.ok then
    log.error("Checkout failed: " .. (r.stderr or ""))
    return false
  end
  log.info("Switched to " .. name)
  return true
end

local function delete_branch(name, force)
  local cmd = force and { "branch", "-D", name } or { "branch", "-d", name }
  local r = runner.run(cmd)
  if not r.ok then
    log.error("Delete failed: " .. (r.stderr or ""))
    return false
  end
  log.info((force and "Force " or "") .. "Deleted branch " .. name)
  return true
end

function M.open()
  layout.ensure()
  refresh()

  local tbuf = layout.state.buf.tree

  map(tbuf, "q", function() layout.close() end, "Close")

  map(tbuf, "j", function() render.select_next(); render.refresh_all(load_data()) end, "Down")
  map(tbuf, "k", function() render.select_prev(); render.refresh_all(load_data()) end, "Up")

  map(tbuf, "<CR>", function()
    local b = render.current_branch()
    if state.view_mode == "compact" then
      -- In compact mode <CR> if on fold region in graph handled there; tree <CR> behaves checkout
    end
    if b and not b.is_head then
      if vim.fn.confirm("Checkout branch '" .. b.name .. "'?", "&Yes\n&No", 2) == 1 then
        if checkout_branch(b.name) then refresh() end
      end
    else
      render.toggle_group()
      render.refresh_all(load_data())
    end
  end, "Checkout / toggle group")

  map(tbuf, "l", function() render.toggle_group(); render.refresh_all(load_data()) end, "Toggle")
  map(tbuf, "h", function() render.toggle_group(); render.refresh_all(load_data()) end, "Toggle")

  map(tbuf, "r", refresh, "Refresh")
  map(tbuf, "g", refresh, "Refresh")

  map(tbuf, "d", function()
    local b = render.current_branch()
    if not b then return end
    if b.is_head then log.warn("Cannot delete HEAD"); return end
    if vim.fn.confirm("Delete branch '" .. b.name .. "'?", "&Yes\n&No", 2) == 1 then
      if delete_branch(b.name, false) then refresh() end
    end
  end, "Delete branch")

  map(tbuf, "D", function()
    local b = render.current_branch()
    if not b then return end
    if b.is_head then log.warn("Cannot delete HEAD"); return end
    if vim.fn.confirm("Force delete branch '" .. b.name .. "'?", "&Yes\n&No", 2) == 1 then
      if delete_branch(b.name, true) then refresh() end
    end
  end, "Force delete branch")

  -- Rotate view
  map(tbuf, "gV", function()
    actions.rotate_view(load_data)
  end, "Rotate view")

  -- Matrix specific sorts
  map(tbuf, "s", function() if state.view_mode=="matrix" then actions.matrix_sort("branch", load_data) end end, "Sort branch")
  map(tbuf, "a", function() if state.view_mode=="matrix" then actions.matrix_sort("ahead", load_data) end end, "Sort ahead")
  map(tbuf, "b", function() if state.view_mode=="matrix" then actions.matrix_sort("behind", load_data) end end, "Sort behind")
  map(tbuf, "u", function() if state.view_mode=="matrix" then actions.matrix_sort("updated", load_data) end end, "Sort updated")
  map(tbuf, "m", function() if state.view_mode=="matrix" then actions.matrix_sort("merged", load_data) end end, "Sort merged")
  map(tbuf, "/", function() if state.view_mode=="matrix" then actions.matrix_filter_prompt(load_data) end end, "Filter")
  map(tbuf, "R", function() if state.view_mode=="matrix" then actions.matrix_reset(load_data) end end, "Reset matrix")

  -- Compact fold ops (graph buffer mappings)
  local gbuf = layout.state.buf.graph
  vim.keymap.set("n","gV", function() actions.rotate_view(load_data) end, { buffer = gbuf, nowait=true, silent=true })
  vim.keymap.set("n","z", function()
    if state.view_mode=="compact" then
      local l = vim.api.nvim_win_get_cursor(layout.state.win.graph)[1]
      actions.compact_toggle_line(l, load_data)
    end
  end, { buffer = gbuf, nowait=true, silent=true })
  vim.keymap.set("n","<CR>", function()
    if state.view_mode=="compact" then
      local l = vim.api.nvim_win_get_cursor(layout.state.win.graph)[1]
      actions.compact_toggle_line(l, load_data)
    end
  end, { buffer = gbuf, nowait=true, silent=true })
  vim.keymap.set("n","E", function()
    if state.view_mode=="compact" then actions.compact_expand_all(load_data) end
  end, { buffer = gbuf, nowait=true, silent=true })
  vim.keymap.set("n","C", function()
    if state.view_mode=="compact" then actions.compact_collapse_all(load_data) end
  end, { buffer = gbuf, nowait=true, silent=true })
end

return M
