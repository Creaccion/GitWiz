-- UI helpers for GitWiz (floating windows, buffers, etc.)
local M = {}

function M.get_branch_info(branch)
	local info = {}

	-- Branch name with icon
	table.insert(info, "  Branch: " .. branch)

	-- Last commit
	local last_commit = vim.fn.system(string.format("git log -1 --pretty=format:'%%h %%s (%%an, %%ar)' %s", branch))
	table.insert(info, "  Last commit: " .. last_commit)

	-- Changed files
	--
	local is_remote = branch:match("^remotes/")
	local changed_files = ""

	# TODO: verificar el caso cuando se compara remotes/origin/HEAD con origin/main
	if branch == "remotes/origin/HEAD" then
		-- Get the actual branch HEAD points to
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

	if changed_files ~= "" then
		table.insert(info, "  Changed files:")
		for file in changed_files:gmatch("[^\r\n]+") do
			table.insert(info, "    " .. file)
		end
	else
		table.insert(info, "No changed files compared to origin.")
	end

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

	return info
end
-- Show branch details in a floating window
function M.show_branch_details(branch)
	-- To be implemented: Display branch info in a floating window
end

return M
