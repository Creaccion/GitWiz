-- UI helpers for GitWiz (floating windows, buffers, etc.)
local M = {}

function M.get_branch_parent_info(branch)
	local main_branch = "main" -- Change to "master" if needed
	local merge_base = vim.fn.system(string.format("git merge-base %s %s", branch, main_branch)):gsub("\n", "")
	if merge_base == "" then
		return { parent_branch = main_branch, base_commit = "No common ancestor found." }
	end
	local commit_info = vim.fn
		.system(string.format("git show --no-patch --format='%%h %%s (%%an, %%ar)' %s", merge_base))
		:gsub("\n", "")
	return {
		parent_branch = main_branch,
		base_commit = commit_info,
	}
end

function M.get_branch_info(branch)
  local info = {}

  -- Branch name
  table.insert(info, "────────────────────────────")
  table.insert(info, "  Branch: " .. branch)
  table.insert(info, "────────────────────────────")
  table.insert(info, "") 
  table.insert(info, "") 
  -- Parent branch and base commit
  local parent_info = M.get_branch_parent_info(branch)
  table.insert(info, "Parent branch: " .. parent_info.parent_branch)
  table.insert(info, "Base commit: " .. parent_info.base_commit)
  table.insert(info, "────────────────────────────")

  table.insert(info, "") 
  table.insert(info, "") 
  -- Last commit
  local last_commit = vim.fn.system(string.format("git log -1 --pretty=format:'%%h %%s (%%an, %%ar)' %s", branch)):gsub("\n", "")
  table.insert(info, "  Last commit: " .. last_commit)
  table.insert(info, "────────────────────────────")

  table.insert(info, "") 
  table.insert(info, "") 
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
-- Show branch details in a floating window
function M.show_branch_details(branch)
	-- To be implemented: Display branch info in a floating window
end

return M
