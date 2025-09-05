
-- graph/actions.lua
local state = require("gitwiz.graph.state")
local render = require("gitwiz.graph.render")
local branches_domain = require("gitwiz.domain.branches")
local log = require("gitwiz.log")

local M = {}

local function reload_branches()
  local res = branches_domain.list({ limit_branch_commits = 8 })
  if not res.ok then
    log.error("Branches reload failed")
    return nil
  end
  return res.data
end

function M.rotate_view(data_provider)
  state.rotate_view()
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

function M.matrix_sort(key, data_provider)
  state.set_matrix_sort(key)
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

function M.matrix_filter_prompt(data_provider)
  local pat = vim.fn.input("Matrix filter (regex, empty clears): ")
  if pat == nil then return end
  pat = vim.trim(pat)
  if pat == "" then
    state.clear_matrix_filter()
  else
    state.set_matrix_filter(pat)
  end
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

function M.matrix_reset(data_provider)
  state.clear_matrix_filter()
  state.set_matrix_sort("branch")
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

-- Compact fold operations
function M.compact_toggle_line(line_nr, data_provider)
  state.compact_toggle_line(line_nr)
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

function M.compact_expand_all(data_provider)
  state.compact_expand_all()
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

function M.compact_collapse_all(data_provider)
  state.compact_collapse_all()
  render.force_refresh_next()
  render.refresh_all(data_provider())
end

return M
