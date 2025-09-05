
local M = {}
local git = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")

function M.list_remotes()
  local ok, result = git.exec_cmd("git remote -v")
  if not ok then return false, result end
  local remotes = vim.split(result, "\n")
  return true, remotes
end

function M.get_remote_details(remote)
  local ok, result = git.exec_cmd("git remote show " .. remote)
  if not ok then return "Failed to get remote details: " .. (result or "") end
  return result
end

return M
