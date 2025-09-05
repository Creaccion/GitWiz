-- api.lua (export revert actions)
local commits_domain = require("gitwiz.domain.commits")
local commits_actions = require("gitwiz.actions.commits")
local events = require("gitwiz.core.events")
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")

local M = {}

M.version = "2.0.0-dev"

M.commits = {
  list = function(opts) return commits_domain.list(opts) end,
}

M.actions = {
  commits = {
    cherry_pick = commits_actions.cherry_pick,
    cherry_pick_many = commits_actions.cherry_pick_many,
    revert = commits_actions.revert,
    revert_many = commits_actions.revert_many,
  },
}

M.events = {
  on = events.on,
  off = events.off,
  clear = events.clear,
}

M.config = {
  get = function()
    return config.get()
  end,
}

M.metrics = function()
  return {
    runner = runner.metrics(),
  }
end

return M
