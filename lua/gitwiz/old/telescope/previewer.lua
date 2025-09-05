local commit_actions = require("gitwiz.actions.commit_actions")
local branch_actions = require("gitwiz.actions.branch_actions")
local telescope_previewers = require("telescope.previewers")
local debug = require("gitwiz.config.debug")

local git_utils = require("gitwiz.utils.git")

local M = {}

M.commit_previewer = telescope_previewers.new_buffer_previewer({
  define_preview = function(self, entry, status)
    local commit_hash = entry.value.hash
    local commit_details = git_utils.get_commit_details(commit_hash)

    local formatted_lines = M.format_commit_details(commit_details)
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, formatted_lines)
  end,
})


-- Format commit details into a structured table of lines with NerdFonts and separators
function M.format_commit_details(commit_details)
  local lines = {}

  -- Add metadata with icons
  table.insert(lines, " Commit: " .. (commit_details.metadata[1] or ""))
  table.insert(lines, " Author: " .. (commit_details.metadata[2] or "") .. " <" .. (commit_details.metadata[3] or "") .. ">")
  table.insert(lines, " Date: " .. (commit_details.metadata[4] or ""))
  table.insert(lines, " Title: " .. (commit_details.metadata[5] or ""))
  table.insert(lines, string.rep("─", 50)) -- Horizontal separator

  -- Add changed files with icon
  table.insert(lines, " Changed Files:")
  if #commit_details.changed_files > 0 then
    for _, file in ipairs(commit_details.changed_files) do
      table.insert(lines, "   " .. file)
    end
  else
    table.insert(lines, "  (No files changed)")
  end
  table.insert(lines, string.rep("─", 50)) -- Horizontal separator

  -- Add diffs with icon
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

-- Format branch details for the previewer
function M.format_branch_details(details)
  local lines = {}
  table.insert(lines, " Branch: " .. (details.branch_name or "Unknown"))
  table.insert(lines, string.rep("-", 60))
  table.insert(lines, " HEAD Commit: " .. (details.head_commit or "Unknown"))
  table.insert(lines, " Created By: " .. (details.branch_author or "Unknown"))
  table.insert(lines, " Creation Date: " .. (details.creation_date or "Unknown"))
  table.insert(lines, " Parent Branch: " .. (details.parent_branch or "Unknown"))
  table.insert(lines, string.rep("-", 60))
  table.insert(lines, string.format("%-10s %-20s %-15s %s", "Hash", "Author", "Date", "Message"))
  table.insert(lines, string.rep("-", 60))
  for _, commit in ipairs(details.commits) do
    local hash, author, date, message = commit:match("^(%S+)%s+(%S+)%s+(%S+)%s+(.+)$")
    table.insert(lines, string.format("%-10s %-20s %-15s %s", hash or "", author or "", date or "", message or ""))
  end
  return lines
end

M.branch_previewer = telescope_previewers.new_buffer_previewer {
  define_preview = function(self, entry, status)
    local ok, details = branch_actions.get_branch_details(entry.value)
    local lines
    if not ok then
      lines = { details.error or "Unknown error" }
    else
      lines = M.format_branch_details(details)
    end
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
  end,
}


return M


