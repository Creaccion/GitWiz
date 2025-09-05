local keymaps = require("gitwiz.config.keymaps")
local telescope_pickers = require("telescope.pickers")
local telescope_finders = require("telescope.finders")
local telescope_config = require("telescope.config")
local commit_actions = require("gitwiz.actions.commit_actions")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")
local utils = require("gitwiz.utils.git")
local previewer = require("gitwiz.telescope.previewer")
local sorters = require("telescope.sorters")
local log = require("gitwiz.log")
local gitwiz_conflicts = require("gitwiz.telescope.conflicts")

local keymap_utils = require("gitwiz.utils.keymap_utils")

local M = {}

-- Picker for listing commits not in the current branch
function M.list_commits(upstream_branch)
  local current_branch = utils.get_current_branch()
  if not current_branch or current_branch == "" then
    print("Error: No branch is currently checked out.")
    return
  end
  local ok, commits = commit_actions.list_commits_not_in_branch(upstream_branch)
  if not ok then
    print("Failed to get commits: " .. (commits or "unknown error"))
    return
  end

  telescope_pickers.new({}, {
    prompt_title = "Commits not in current branch",
    finder = telescope_finders.new_table {
      results = commits,
    },
    sorter = telescope_config.values.generic_sorter({}),
    attach_mappings = function(_, map)
      map("i", "<CR>", function(prompt_bufnr)
        local commit_hash = action_state.get_selected_entry().value:match("^[^ ]+")
        commit_actions.cherry_pick_commit(commit_hash)
        actions.close(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

-- Internal: build results with branch membership
local function build_commit_results()
  local branch = utils.get_current_branch()
  local git_log_output = vim.fn.systemlist("git log --all --pretty=format:'%h|%s|%an|%ad' --date=short")
  local results = {}
  for _, log_entry in ipairs(git_log_output) do
    local hash, title, author, date = log_entry:match("^(%S+)|([^|]+)|([^|]+)|([^|]+)$")
    if hash and title and author and date then
      local in_branch = utils.is_commit_in_branch(hash, branch)
      local symbol = in_branch and "✔" or "✘"
      table.insert(results, {
        symbol = symbol,
        hash = hash,
        title = title,
        author = author,
        date = date,
      })
    end
  end
  return results
end

-- Refresh current picker with updated commit symbols
local function refresh_picker(picker)
  picker:refresh(telescope_finders.new_table({
    results = build_commit_results(),
    entry_maker = function(entry)
      return {
        value = entry,
        display = string.format("%-3s %-30s %-20s %-12s %-12s", entry.symbol, entry.title, entry.author, entry.date, entry.hash),
        ordinal = entry.symbol .. " " .. entry.title .. " " .. entry.author .. " " .. entry.date .. " " .. entry.hash,
      }
    end,
  }), { reset_prompt = false })
end

-- Picker to list all commits
function M.list_all_commits_picker()
  local base_attach = keymap_utils.generate_attach_mappings(keymaps)

  telescope_pickers.new({}, {
    prompt_title = "Git Commits",
    finder = telescope_finders.new_table({
      results = build_commit_results(),
      entry_maker = function(entry)
        return {
          value = entry,
          display = string.format("%-3s %-30s %-20s %-12s %-12s", entry.symbol, entry.title, entry.author, entry.date, entry.hash),
          ordinal = entry.symbol .. " " .. entry.title .. " " .. entry.author .. " " .. entry.date .. " " .. entry.hash,
        }
      end,
    }),
    sorter = sorters.get_generic_fuzzy_sorter(),
    previewer = previewer.commit_previewer,
    attach_mappings = function(prompt_bufnr, map)
      if base_attach then base_attach(prompt_bufnr, map) end

      local picker = action_state.get_current_picker(prompt_bufnr)

      local function extract_hash(entry)
        if entry and entry.value and entry.value.hash then
          return entry.value.hash
        end
      end

      local function open_conflicts_picker()
        gitwiz_conflicts.open()
      end

      local function do_cherry_pick()
        local selections = picker:get_multi_selection()
        if #selections == 0 then
          selections = { action_state.get_selected_entry() }
        end
        local hashes = {}
        for _, sel in ipairs(selections) do
          local h = extract_hash(sel)
            if h then table.insert(hashes, h) end
        end
        if #hashes == 0 then
          log.warn("No commit hash resolved for cherry-pick")
          return
        end
        local ok, data = commit_actions.cherry_pick_commits(hashes)
        if ok then
          log.info("Cherry-pick finished count=" .. #data.applied)
          refresh_picker(picker)
        else
          if data.reason == "conflicts" then
            log.warn("Cherry-pick stopped: conflicts (" .. #data.conflicts .. " files)")
            -- Open conflicts picker without closing current one
            open_conflicts_picker()
          else
            log.error("Cherry-pick failed: " .. (data.stderr or data.reason))
          end
          refresh_picker(picker)
        end
      end

      map("i", "<C-p>", do_cherry_pick)
      map("n", "<C-p>", do_cherry_pick)
      map("i", "<C-f>", open_conflicts_picker)
      map("n", "<C-f>", open_conflicts_picker)

      return true
    end,
  }):find()
end

return M
