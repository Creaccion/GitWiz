-- UI helpers for branch preview in GitWiz
local M = {}

local debug = require("gitwiz.config.debug")
local function show_branch_relationship(current_branch, target_branch)
	local ahead = tonumber(vim.fn.system("git rev-list --count " .. target_branch .. ".." .. current_branch))
	local behind = tonumber(vim.fn.system("git rev-list --count " .. current_branch .. ".." .. target_branch))
	local lines = {}
	table.insert(
		lines,
		string.format("%s is %d commits ahead and %d behind %s", current_branch, ahead, behind, target_branch)
	)
	return lines
end

-- Check if fast-forward is possible (base branch is behind current)
function M.can_fast_forward(current_branch, base_branch)
  local behind = tonumber(vim.fn.system("git rev-list --count " .. current_branch .. ".." .. base_branch))
  return behind > 0
end

function M.branch_relationship(current_branch, target_branch)
  local ahead = tonumber(vim.fn.system("git rev-list --count " .. target_branch .. ".." .. current_branch))
  local behind = tonumber(vim.fn.system("git rev-list --count " .. current_branch .. ".." .. target_branch))
  local lines = {}
  table.insert(lines, string.format("%s is %d commits ahead and %d behind %s", current_branch, ahead, behind, target_branch))
  if behind > 0 then
    table.insert(lines, "⚠️  After rebase, the base branch pointer was not advanced.")
    table.insert(lines, "To fully synchronize, fast-forward the base branch:")
    table.insert(lines, string.format("git checkout %s && git merge --ff-only %s", target_branch, current_branch))
  end
  return lines
end

function M.format_branch_info(branch, opts)
	opts = opts or {}
	local info = {}

	table.insert(info, "  Branch: " .. branch)
	table.insert(info, "────────────────────────────")

	-- Parent branch and base commit
	local main_branch = opts.main_branch or "main"
	local merge_base = vim.fn.system(string.format("git merge-base %s %s", branch, main_branch)):gsub("\n", "")
	local parent_info = "Parent branch: " .. main_branch
	local base_commit = "Base commit: "
	if merge_base ~= "" then
		local commit_info = vim.fn
			.system(string.format("git show --no-patch --format='%%h %%s (%%an, %%ar)' %s", merge_base))
			:gsub("\n", "")
		base_commit = base_commit .. commit_info
	else
		base_commit = base_commit .. "No common ancestor found."
	end
	table.insert(info, parent_info)
	table.insert(info, base_commit)
	table.insert(info, "────────────────────────────")

	-- Last commit
	local last_commit =
		vim.fn.system(string.format("git log -1 --pretty=format:'%%h %%s (%%an, %%ar)' %s", branch)):gsub("\n", "")
	table.insert(info, "  Last commit: " .. last_commit)
	table.insert(info, "────────────────────────────")

	-- Changed files
	local is_remote = branch:match("^remotes/")
	local changed_files = ""
	if branch == "remotes/origin/HEAD" then
		local head_target = vim.fn.system("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null")
		local main_branch = head_target:match("refs/remotes/origin/(.+)")
		if main_branch then
			local origin_branch = "origin/" .. main_branch
			local origin_exists = vim.fn.system(string.format("git rev-parse --verify %s", origin_branch))
			if vim.v.shell_error == 0 then
				changed_files = vim.fn.system(string.format("git diff --name-only %s %s", branch, origin_branch))
			else
				changed_files = vim.fn.system(string.format("git diff --name-only %s", branch))
			end
		else
			changed_files = "Could not resolve origin/HEAD target branch."
		end
	elseif is_remote then
		changed_files = vim.fn.system(string.format("git show --pretty='' --name-only %s", branch))
	else
		local origin_branch = "origin/" .. branch
		local origin_exists = vim.fn.system(string.format("git rev-parse --verify %s", origin_branch))
		if vim.v.shell_error == 0 then
			changed_files = vim.fn.system(string.format("git diff --name-only %s %s", branch, origin_branch))
		else
			changed_files = vim.fn.system(string.format("git diff --name-only %s", branch))
		end
	end
	table.insert(info, "  Changed files:")
	if changed_files ~= "" then
		for file in changed_files:gmatch("[^\r\n]+") do
			table.insert(info, "    " .. file)
		end
	else
		table.insert(info, "   No changed files.")
	end
	table.insert(info, "────────────────────────────")

	-- Recent authors
	local authors = vim.fn.system(string.format("git log %s --pretty=format:'%%an'", branch))
	local unique_authors = {}
	for author in authors:gmatch("[^\r\n]+") do
		unique_authors[author] = true
	end
	local author_list = {}
	for author, _ in pairs(unique_authors) do
		table.insert(author_list, " " .. author)
	end
	table.insert(info, "Recent authors: " .. table.concat(author_list, ", "))
	table.insert(info, "────────────────────────────")

	return info
end

return M
