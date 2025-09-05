local M = {}
local git = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")

function M.list_commits(opts)
	opts = opts or {}
	local cmd = "git log --oneline --decorate=short --color=never"
	local ok, result = git.exec_cmd(cmd)
	if not ok then
		return false, result
	end
	local commits = {}
	for line in result:gmatch("[^\r\n]+") do
		table.insert(commits, line)
	end
	return true, commits
end

function M.git_show(commit, file)
	if not commit or not file then
		return false, { "Error: Commit hash or file path is missing." }
	end

	local cmd = { "git", "show", commit .. ":" .. file }
	local result = vim.fn.systemlist(cmd)

	if vim.v.shell_error ~= 0 then
		return false, { "Error: Unable to read file from commit.", "File: " .. file, "Commit: " .. commit }
	end

	return true, result
end

function M.get_commit_file_details(commit, file)
	if not commit then
		return false, { "Error: Commit hash is missing." }
	end

	if not file then
		return false, { "Error: File name is missing." }
	end

	-- Obtener detalles básicos del commit
	local cmd_details = { "git", "show", "--no-patch", "--pretty=format:%an%n%ad%n%s", commit }
	print("Executing git show details command:", table.concat(cmd_details, " ")) -- Debugging
	local ok, details_result = vim.fn.systemlist(cmd_details)

	if not ok then
		return false, details_result
	end

	local author = details_result[1]
	local date = details_result[2]
	local message = details_result[3]

	-- Obtener el contenido del archivo usando `git show`
	local cmd_diff = { "git", "show", commit .. ":" .. file }
	print("Executing git show file command:", table.concat(cmd_diff, " ")) -- Debugging
	local ok, details_result = git.exec_cmd(cmd_details)

	if vim.v.shell_error ~= 0 then
		return false,
		    { "Error: Unable to fetch file content from commit.", "File: " .. file, "Commit: " .. commit }
	end

	return true, {
		author = author,
		date = date,
		message = message,
		diff = diff_result,
		hash = commit,
	}
end

function M.get_commit_details(commit)
	if not commit then
		return false, { "Error: Commit hash is missing." }
	end

	local details = {}
	-- Obtener detalles básicos del commit
	local ok, raw_result = git.exec_cmd("git show --format='%an%n%ad%n%s' " .. commit)
	if not ok then
		return false, raw_result
	end
	local lines = vim.split(raw_result, "\n", { plain = true, trimempty = true })


	if #lines >= 3 then
		details.author = lines[1]
		details.date = lines[2]
		details.message = lines[3]
	else
		details.author = "Unknown"
		details.date = "Unknown"
		details.message = "No commit message"
	end
	details.hash = commit

	-- Obtener el contenido del archivo usando `git show`
	details.diff = {}
	for i = 4, #lines do
		table.insert(details.diff, lines[i])
	end
	-- Get files changed in the commit
	local files = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. commit)
	details.files = files

	return true, details
end

function M.search_commits_by_text(text)
	if not text or text == "" then
		return false, "Search text required"
	end
	local cmd = "git log --all --grep='" .. text .. "' --oneline --decorate=short --color=never"
	local ok, result = git.exec_cmd(cmd)
	if not ok then
		return false, result
	end
	local commits = vim.split(result, "\n")
	return true, commits
end

function M.cherry_pick_commit(commit_hash)
	if not commit_hash or commit_hash == "" then
		return false, "Commit hash is required"
	end
	local ok, result = git.exec_cmd("git cherry-pick " .. commit_hash)
	if not ok then
		return false, "Cherry-pick failed for commit " .. commit_hash .. ": " .. (result or "")
	end
	return true, "Cherry-picked commit: " .. commit_hash
end

function M.get_file_at_commit(commit_hash, file_path)
	if not commit_hash or not file_path then
		return false, "Commit hash and file path required"
	end
	local ok, result = git.exec_cmd("git show " .. commit_hash .. ":" .. file_path)
	if not ok then
		return false, "Failed to get file at commit: " .. (result or "")
	end
	return true, result
end

return M
