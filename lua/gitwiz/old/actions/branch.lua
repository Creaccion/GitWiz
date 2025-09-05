-- Branch actions for GitWiz
local M = {}
local git = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")

function M.create_branch(branch_name, base_branch)
  local args = string.format("branch %s %s", branch_name, base_branch or "")
  local ok, result = git.exec(args)
  if not ok then
    print("Branch creation failed: " .. result)
    return false, result
  else
    print("Branch created: " .. branch_name)
    return true, result
  end
end

function M.get_branch_details(branch_name)
  if not branch_name or branch_name == "" then
    return false, { error = "No branch name provided" }
  end
  -- Último commit en la rama
  local ok, log = git.exec_cmd("git log -1 --pretty=format:'%H|%an|%ad|%s' " .. branch_name)
  if not ok then
    return false, { error = "Failed to get branch details: " .. (log or "") }
  end
  local hash, author, date, message = log:match("([^|]+)|([^|]+)|([^|]+)|(.+)")
  -- Commits únicos en la rama respecto a main/master
  local ok2, unique = git.exec_cmd("git log " .. branch_name .. " --not main --oneline --decorate=short --color=never")
  if not ok2 then unique = "" end
  local unique_commits = vim.split(unique, "\n")
  -- Archivos modificados en el último commit
  local ok3, files = git.exec_cmd("git show --stat --oneline --color=never " .. (hash or ""))
  if not ok3 then files = "" end
  local files_changed = {}
  for _, line in ipairs(vim.split(files, "\n")) do
    if line:match("|") then
      table.insert(files_changed, line)
    end
  end
  return true, {
    branch = branch_name,
    hash = hash,
    author = author,
    date = date,
    message = message,
    files = files_changed,
    unique_commits = unique_commits,
  }
end


-- Returns a table of branch names (strings)
function M.list_branches(opts)
  opts = opts or {}
  local cmd = opts.all and "git branch --all --color=never" or "git branch --color=never"
  local handle = io.popen(cmd)
  if not handle or type(handle) ~= "userdata" then
    return false, "Failed to run git branch: io.popen returned nil"
  end
  local result = handle:read("*a")
  handle:close()
  local branches = {}
  for line in result:gmatch("[^\r\n]+") do
    local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
    table.insert(branches, branch)
  end
  return true, branches
end

function M.checkout_branch(branch)
  local args = string.format("checkout %s", branch)
  local ok, result = git.exec(args)
  if not ok then
    print("Checkout failed: " .. result)
    return false, result
  else
    print("Checked out to branch: " .. branch)
    return true, result
  end
end

function M.rename_branch(old_name, new_name)
  local args = string.format("branch -m %s %s", old_name, new_name)
  local ok, result = git.exec(args)
  if not ok then
    print("Branch rename failed: " .. result)
    return false, result
  else
    print(string.format("Branch renamed: %s → %s", old_name, new_name))
    return true, result
  end
end

function M.delete_branch(branch_name)
  local args = string.format("branch -d %s", branch_name)
  local ok, result = git.exec(args)
  if not ok then
    print("Branch deletion failed: " .. result)
    return false, result
  else
    print("Branch deleted: " .. branch_name)
    return true, result
  end
end
--
-- Merge a branch into the current branch
function M.merge_branch(target_branch)
  local args = string.format("merge %s", target_branch)
  local ok, result = require("gitwiz.utils.git").exec(args)
  if not ok then
    print("Branch merge failed: " .. result)
    return false, result
  else
    print("Branch merged: " .. target_branch)
    return true, result
  end
end

function M.merge_into_branch(base_branch, target_branch)
  local checkout_ok, checkout_result = M.checkout_branch(base_branch)
  if not checkout_ok then
    print("Failed to checkout base branch: " .. checkout_result)
    return false, checkout_result
  end
  return M.merge_branch(target_branch)
end
--
-- Interactive rebase onto a target branch (UI-only, no editor)
function M.interactive_rebase_onto(target_branch)
  local cmd = string.format("GIT_SEQUENCE_EDITOR='true' git rebase -i %s", target_branch)
  local ok, result = require("gitwiz.utils.git").exec_cmd(cmd)
  print("Rebase command result:", result)
  if not ok then
    print("Interactive rebase failed: " .. result)
    return false, result
  else
    print("Interactive rebase started (UI only) onto: " .. target_branch)
    return true, result
  end
end

return M
