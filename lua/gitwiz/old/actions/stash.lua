local M = {}
local git = require("gitwiz.utils.git")

local debug = require("gitwiz.config.debug")
function M.list_stashes()
	local ok, result = git.exec_cmd("git stash list")
	if not ok then return false, result end
	local stashes = vim.split(result, "\n")
	return true, stashes
end

function M.get_stash_details(stash_ref)
	if not stash_ref or stash_ref == "" then
		return false, { error = "No stash reference provided" }
	end
	local ok, result = git.exec_cmd("git stash show -p " .. stash_ref)
	if not ok then
		return false, { error = "Failed to get stash details: " .. (result or "") }
	end

	-- Extrae archivos y diff
	local lines = vim.split(result, "\n")
	local files = {}
	local diff = {}
	local in_diff = false
	for _, line in ipairs(lines) do
		if line:match("^diff") or line:match("^@@") then
			in_diff = true
			table.insert(diff, line)
		elseif in_diff then
			table.insert(diff, line)
		elseif line:match("|") then
			table.insert(files, line)
		end
	end

	return true, {
		ref = stash_ref,
		files = files,
		diff = diff,
		-- Puedes agregar más campos si logras extraer rama base, fecha, etc.
	}
end

function M.apply_stash(stash_ref)
	if not stash_ref or stash_ref == "" then
		return false, "Stash reference required"
	end
	local ok, result = git.exec_cmd("git stash apply " .. stash_ref)
	if not ok then
		return false, "Failed to apply stash: " .. (result or "")
	end
	return true, "Stash applied: " .. stash_ref
end

function M.drop_stash(stash_ref)
	if not stash_ref or stash_ref == "" then
		return false, "Stash reference required"
	end
	local ok, result = git.exec_cmd("git stash drop " .. stash_ref)
	if not ok then
		return false, "Failed to drop stash: " .. (result or "")
	end
	return true, "Stash dropped: " .. stash_ref
end

return M
