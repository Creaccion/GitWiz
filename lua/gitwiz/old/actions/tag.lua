local M = {}
local git = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")

function M.list_tags()
  local ok, result = git.exec_cmd("git tag --list")
  if not ok then return false, result end
  local tags = vim.split(result, "\n")
  return true, tags
end

function M.get_tag_details(tag)
  local ok, result = git.exec_cmd("git show --color=never " .. tag)
  if not ok then return "Failed to get tag details: " .. (result or "") end
  return result
end

function M.checkout_tag(tag)
  if not tag or tag == "" then
    return false, "Tag is required"
  end
  local ok, result = git.exec_cmd("git checkout " .. tag)
  if not ok then
    return false, "Failed to checkout tag: " .. (result or "")
  end
  return true, "Checked out tag: " .. tag
end

function M.delete_tag(tag)
  if not tag or tag == "" then
    return false, "Tag is required"
  end
  local ok, result = git.exec_cmd("git tag -d " .. tag)
  if not ok then
    return false, "Failed to delete tag: " .. (result or "")
  end
  return true, "Deleted tag: " .. tag
end
return M

