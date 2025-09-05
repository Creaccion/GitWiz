local ui_help = require("gitwiz.ui.help")
local utils = require("gitwiz.utils.git")
local branch_actions = require("gitwiz.actions.branch_actions")
local git_utils = require("gitwiz.utils.git")
local debug = require("gitwiz.config.debug")

local M = {}

function M.attach_mappings(_, map)
  local keymaps = {}
  map("i", "<C-h>", function()
    ui_help.show_help(keymaps)
  end)
  return true
end

function M.select_commit(commit)
  local commit_hash = commit:match("^(%S+)")
  local commit_details = git_utils.get_commit_details(commit_hash)
  debug.info("Commit selected:", commit_hash)
  for _, line in ipairs(commit_details.metadata or {}) do
    debug.debug("Meta:", line)
  end
end

function M.checkout_commit(commit_hash)
  vim.fn.system("git checkout " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Checkout failed:", commit_hash)
  else
    debug.info("Checked out commit:", commit_hash)
  end
end

function M.create_branch_from_commit(commit_hash, branch_name)
  vim.fn.system("git branch " .. branch_name .. " " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Failed to create branch from commit:", commit_hash, "->", branch_name)
  else
    debug.info("Branch created from commit:", commit_hash, "as", branch_name)
  end
end

function M.revert_commit(commit_hash)
  vim.fn.system("git revert " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Revert failed:", commit_hash)
  else
    debug.info("Reverted commit:", commit_hash)
  end
end

function M.cherry_pick_commit(commit_hash)
  local result = vim.fn.system("git cherry-pick " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Cherry-pick failed:", commit_hash, "out:", result)
    return false, result
  end
  debug.info("Cherry-picked commit:", commit_hash)
  return true, result
end

-- Returns list of files in conflict (might be empty)
function M.get_conflicts()
  return vim.fn.systemlist("git diff --name-only --diff-filter=U")
end

-- Multi cherry-pick with conflict detection.
-- Applies commits in reverse order.
function M.cherry_pick_commits(hashes)
  if not hashes or #hashes == 0 then
    return false, { reason = "empty", message = "No commits provided" }
  end
  debug.info("Starting multi cherry-pick count=" .. #hashes)
  local applied = {}
  for i = #hashes, 1, -1 do
    local hash = hashes[i]
    debug.debug("Cherry-pick attempt:", hash)
    local ok, out = M.cherry_pick_commit(hash)
    if not ok then
      local conflicts = M.get_conflicts()
      if #conflicts > 0 then
        debug.warn("Conflicts after cherry-pick: " .. hash)
        return false, {
          reason = "conflicts",
          last = hash,
          applied = applied,
          conflicts = conflicts,
          stderr = out,
        }
      end
      debug.error("Cherry-pick error (no conflicts detected): " .. hash)
      return false, {
        reason = "error",
        last = hash,
        applied = applied,
        stderr = out,
      }
    end
    table.insert(applied, hash)
  end
  debug.info("Multi cherry-pick complete applied=" .. #applied)
  return true, { applied = applied }
end

function M.list_all_commits()
  local handle = io.popen("git log --oneline 2>/dev/null")
  if not handle then
    debug.error("Failed to open git log pipe")
    return
  end
  local commits = handle:read("*a")
  handle:close()
  if not commits or commits == "" then
    debug.warn("No commits found in repository")
    return
  end
  debug.debug("All commits fetched")
  return vim.split(commits, "\n")
end

function M.list_current_branch_commits()
  local current_branch = utils.get_current_branch()
  if not current_branch or current_branch == "" then
    debug.warn("Current branch not detected")
    return
  end
  local handle = io.popen("git log " .. current_branch .. " --oneline")
  if not handle then
    debug.error("Failed to open git log for branch:", current_branch)
    return
  end
  local commits = handle:read("*a")
  handle:close()
  if not commits or commits == "" then
    debug.warn("No commits retrieved for branch:", current_branch)
    return
  end
  debug.debug("Branch commits fetched:", current_branch)
  return vim.split(commits, "\n")
end

function M.get_commit_details(commit_hash)
  if not commit_hash then
    return false, { "Missing commit hash" }
  end
  local ok, raw_result = git_utils.exec_cmd("git show --format='%an%n%ad%n%s' " .. commit_hash)
  if not ok then
    debug.error("Failed to get commit details:", commit_hash)
    return false, raw_result
  end
  local lines = vim.split(raw_result, "\n", { plain = true, trimempty = true })
  local details = {}
  if #lines >= 3 then
    details.author = lines[1]
    details.date = lines[2]
    details.message = lines[3]
  else
    details.author = "Unknown"
    details.date = "Unknown"
    details.message = "No commit message"
  end
  details.hash = commit_hash
  details.diff = {}
  for i = 4, #lines do
    table.insert(details.diff, lines[i])
  end
  local files = vim.fn.systemlist("git diff-tree --no-commit-id --name-only -r " .. commit_hash)
  details.files = files
  debug.debug("Parsed commit details:", commit_hash)
  return true, details
end

function M.show_diff(commit_hash)
  commit_hash = vim.trim(commit_hash):match("^[^ ]+")
  debug.info("Showing diff for commit:", commit_hash)
  local diff = vim.fn.systemlist("git show " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Failed to retrieve diff:", commit_hash)
    return
  end
  vim.cmd("split")
  vim.cmd("resize 15")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
end

function M.copy_commit_hash(commit_hash)
  vim.fn.setreg("+", commit_hash)
  debug.info("Copied commit hash:", commit_hash)
end

function M.open_in_browser(commit_hash)
  local remote_url = vim.fn.system("git config --get remote.origin.url")
  if vim.v.shell_error ~= 0 or remote_url == "" then
    debug.error("Remote URL retrieval failed")
    return
  end
  remote_url = remote_url:gsub("git@github.com:", "https://github.com/"):gsub("%.git", "")
  local commit_url = remote_url .. "/commit/" .. commit_hash
  vim.fn.system("open " .. commit_url)
  debug.info("Opened commit in browser:", commit_url)
end

function M.tag_commit(commit_hash, tag_name)
  local result = vim.fn.system("git tag " .. tag_name .. " " .. commit_hash)
  if vim.v.shell_error ~= 0 then
    debug.error("Failed to tag commit:", commit_hash, "tag:", tag_name, "out:", result)
    return
  end
  debug.info("Tagged commit:", commit_hash, "as", tag_name)
end

function M.compare_with_head(commit_hash)
  local diff = vim.fn.systemlist("git diff " .. commit_hash .. " HEAD")
  if vim.v.shell_error ~= 0 then
    debug.error("Compare with HEAD failed:", commit_hash)
    return
  end
  vim.cmd("vsplit")
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, diff)
  vim.api.nvim_set_current_buf(buf)
  vim.api.nvim_buf_set_option(buf, "modifiable", false)
  vim.api.nvim_buf_set_option(buf, "filetype", "diff")
  debug.info("Opened comparison diff for commit:", commit_hash)
end

function M.list_commits_not_in_branch(upstream_branch)
  if not upstream_branch or upstream_branch == "" then
    local main_branch, err = utils.get_main_branch()
    if not main_branch then
      return false, err
    end
    upstream_branch = main_branch
  end
  vim.fn.system("git fetch origin " .. upstream_branch)
  if vim.v.shell_error ~= 0 then
    debug.error("Fetch failed for branch:", upstream_branch)
    return false, "Failed to fetch upstream branch: " .. upstream_branch
  end
  local current_branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")
  if vim.v.shell_error ~= 0 then
    return false, "Failed to retrieve current branch"
  end
  debug.info("Comparing branches:", current_branch, "vs", upstream_branch)
  local command = "git log " .. current_branch .. ".." .. upstream_branch .. " --oneline"
  debug.debug("Executing:", command)
  local commits = vim.fn.systemlist(command)
  if vim.v.shell_error ~= 0 then
    debug.error("Failed to list commits diff range")
    return false, "Failed to retrieve commits not in branch: " .. current_branch
  end
  return true, commits
end

return M
