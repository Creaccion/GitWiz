local M = {}
local utils = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")
-- Get details of a branch
function M.get_branch_details(branch_name)
	local details = {}

	-- Add the branch name
	details.branch_name = branch_name

	-- Get the commits of the branch
	local commits = vim.fn.systemlist("git log --format='%h %an %ar %s' " .. branch_name)
	if vim.v.shell_error ~= 0 then
		return false, { error = "Failed to retrieve commits for branch: " .. branch_name }
	end
	details.commits = commits

	-- Get the HEAD commit hash
	local head_commit = vim.fn.system("git rev-parse " .. branch_name)
	if vim.v.shell_error ~= 0 then
		return false, { error = "Failed to retrieve HEAD commit for branch: " .. branch_name }
	end
	details.head_commit = vim.trim(head_commit)

	-- Get the creation date of the branch
	local creation_date = vim.fn.system("git reflog show --date=iso " ..
		branch_name .. " | tail -1 | awk '{print $1, $2}'")
	if vim.v.shell_error ~= 0 then
		details.creation_date = "Unknown"
	else
		details.creation_date = vim.trim(creation_date)
	end

        local main_branch, err = utils.get_main_branch()
	if not main_branch then
	  print("Error: " .. err)
	  return
	end
	-- Get the author of the first commit in the branch
	local branch_author = vim.fn.system("git log --format='%an' " .. branch_name .. " | tail -1")
	if vim.v.shell_error ~= 0 then
		details.branch_author = "Unknown"
	else
		details.branch_author = vim.trim(branch_author)
	end

	-- Get the parent branch (merge-base with main)
	local parent_branch = vim.fn.system("git merge-base " .. branch_name .. " main")
	if vim.v.shell_error ~= 0 then
		details.parent_branch = "Unknown"
	else
		details.parent_branch = vim.trim(parent_branch)
	end

	return true, details
end

return M
