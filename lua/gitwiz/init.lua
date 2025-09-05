-- init.lua (added GitWizGraph command)
local config = require("gitwiz.core.config")
local log = require("gitwiz.log")
local events = require("gitwiz.core.events")

local M = {}

local MIN_VERSION = "nvim-0.10"

local function check_version()
  if vim.fn.has(MIN_VERSION) == 0 then
    vim.schedule(function()
      vim.notify("GitWiz requires Neovim 0.10 or newer", vim.log.levels.ERROR)
    end)
    return false
  end
  return true
end

local function debug_notify(msg)
  vim.schedule(function()
    vim.notify("[GitWiz] " .. msg, vim.log.levels.DEBUG)
  end)
end

function M.setup(opts)
  if type(opts) ~= "table" then
    opts = {}
  end

  if not check_version() then
    return
  end

  config.setup(opts)

  if type(opts.log) == "table" and opts.log.level then
    require("gitwiz.log").set_level(opts.log.level)
  end

  vim.api.nvim_create_user_command("GitWizCommitsV2", function()
    package.loaded["gitwiz.ui.telescope.commits"] = nil
    package.loaded["gitwiz.ui.telescope.adapter_commits"] = nil
    local ok, mod = pcall(require, "gitwiz.ui.telescope.adapter_commits")
    if not ok then
      vim.notify("GitWiz: cannot load commits adapter: " .. tostring(mod), vim.log.levels.ERROR)
      return
    end
    if type(mod) ~= "table" or type(mod.open) ~= "function" then
      vim.notify("GitWiz: adapter invalid (type=" .. type(mod) .. ")", vim.log.levels.ERROR)
      return
    end
    local ok_open, err = pcall(mod.open, {})
    if not ok_open then
      vim.notify("GitWiz: error opening commits UI: " .. tostring(err), vim.log.levels.ERROR)
    end
  end, {})

  vim.api.nvim_create_user_command("GitWizConflicts", function()
    local ok, conflicts = pcall(require, "gitwiz.conflicts")
    if not ok then
      vim.notify("GitWiz: cannot load conflicts UI: " .. tostring(conflicts), vim.log.levels.ERROR)
      return
    end
    conflicts.toggle()
  end, {})

  vim.api.nvim_create_user_command("GitWizGraph", function()
    local ok, graph = pcall(require, "gitwiz.graph")
    if not ok then
      vim.notify("GitWiz: cannot load graph: " .. tostring(graph), vim.log.levels.ERROR)
      return
    end
    graph.open()
  end, {})

  local ok_conf, conflicts = pcall(require, "gitwiz.conflicts")
  if ok_conf and type(conflicts) == "table" then
    events.on("cherry_pick:conflict", function() conflicts.on_conflict_event() end)
    events.on("revert:conflict", function() conflicts.on_conflict_event() end)
  else
    log.warn("GitWiz: conflicts module not available for event hooks")
  end

  debug_notify("initialized")
end

return M
