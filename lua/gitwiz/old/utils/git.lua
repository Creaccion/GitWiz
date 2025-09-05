local M = {}
local log = require("gitwiz.log")

function M.exec(args)
  local cmd = "git " .. args
  local result = vim.fn.system(cmd)
  local ok = vim.v.shell_error == 0
  if not ok then
    log.error(string.format("Git exec failed: %s exit=%d out=%s", cmd, vim.v.shell_error, result))
  else
    log.debug("Git exec ok: " .. cmd)
  end
  return ok, result
end

function M.exec_cmd(cmd)
  local result = vim.fn.system(cmd)
  local ok = vim.v.shell_error == 0
  if not ok then
    log.error(string.format("Git exec_cmd failed: %s exit=%d out=%s", cmd, vim.v.shell_error, result))
  else
    log.debug("Git exec_cmd ok: " .. cmd)
  end
  return ok, result
end

-- Get the current branch name
function M.get_current_branch()
  local handle = io.popen("git rev-parse --abbrev-ref HEAD")
  if not handle then
    log.error("Failed to open process for current branch")
    return ""
  end
  local branch = handle:read("*a"):gsub("%s+", "")
  handle:close()
  log.debug("Current branch detected: " .. branch)
  return branch
end

function M.get_main_branch()
  log.debug("Starting get_main_branch")
  local handle = io.popen("git remote")
  if not handle then
    log.error("Failed to run git remote")
    return nil, "Failed to detect remotes"
  end
  local remotes = handle:read("*a")
  handle:close()
  log.debug("Remotes: " .. remotes)

  if remotes == nil or remotes == "" then
    log.info("No remotes found, searching local default branches")
    local default_branches = { "main", "master" }
    for _, branch in ipairs(default_branches) do
      local h = io.popen("git branch --list " .. branch)
      if h then
        local result = h:read("*a")
        h:close()
        log.debug(string.format("Check branch: %s result: %s", branch, result))
        if result and result ~= "" then
          return branch:gsub("%s+", ""), nil
        end
      end
    end
    return nil, "No remote and no local default branch"
  end

  local h2 = io.popen("git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null")
  if not h2 then
    log.error("Failed to read origin/HEAD symbolic ref")
    return nil, "No symbolic ref"
  end
  local ref = h2:read("*a")
  h2:close()
  log.debug("Symbolic-ref result: " .. (ref or ""))
  if ref == nil or ref == "" then
    return nil, "Failed to fetch upstream branch: No symbolic ref found"
  end
  local main_branch = ref:match("refs/remotes/origin/(.*)")
  log.info("Main branch resolved: " .. (main_branch or ""))
  return main_branch, nil
end

function M.is_commit_in_branch(commit_hash, branch)
  if not commit_hash or commit_hash == "" or not branch or branch == "" then
    return false
  end
  local branches = vim.fn.systemlist("git branch --contains " .. commit_hash)
  for _, b in ipairs(branches) do
    if b:match(branch) then
      log.debug(string.format("Commit %s is in branch %s", commit_hash, branch))
      return true
    end
  end
  return false
end

function M.get_commit_details(commit_hash)
  local metadata = vim.fn.systemlist("git show --no-patch --pretty=format:'%H%n%an%n%ae%n%ad%n%s' " .. commit_hash)
  local changed_files = vim.fn.systemlist("git show --name-only --pretty=format:'' " .. commit_hash)
  local diffs = vim.fn.systemlist("git show --pretty=format:'' " .. commit_hash)
  log.debug("Fetched commit details: " .. commit_hash)
  return {
    metadata = metadata,
    changed_files = changed_files,
    diffs = diffs,
  }
end

function M.format_commit_details(commit_details)
  local lines = {}
  table.insert(lines, " Commit: " .. (commit_details.metadata[1] or ""))
  table.insert(lines, " Author: " .. (commit_details.metadata[2] or "") .. " <" .. (commit_details.metadata[3] or "") .. ">")
  table.insert(lines, " Date: " .. (commit_details.metadata[4] or ""))
  table.insert(lines, " Title: " .. (commit_details.metadata[5] or ""))
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, " Changed Files:")
  if #commit_details.changed_files > 0 then
    for _, file in ipairs(commit_details.changed_files) do
      table.insert(lines, "   " .. file)
    end
  else
    table.insert(lines, "  (No files changed)")
  end
  table.insert(lines, string.rep("─", 50))
  table.insert(lines, " Diffs:")
  if #commit_details.diffs > 0 then
    for _, diff in ipairs(commit_details.diffs) do
      table.insert(lines, "  " .. diff)
    end
  else
    table.insert(lines, "  (No diffs available)")
  end
  return lines
end

return M
