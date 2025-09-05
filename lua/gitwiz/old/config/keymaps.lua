local commit_actions = require("gitwiz.actions.commit_actions")
local action_state = require("telescope.actions.state")
local actions = require("telescope.actions")

local debug = require("gitwiz.config.debug")
local M = {}

-- Base structure for keymaps and actions
local base_keymaps = {
  {
    key = "<CR>",
    desc = "Checkout the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.checkout_commit(commit_hash)
      actions.close(prompt_bufnr)
    end,
  },
  {
    key = "<C-b>",
    desc = "Create a new branch from the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      local branch_name = vim.fn.input("Branch name: ")
      commit_actions.create_branch_from_commit(commit_hash, branch_name)
      actions.close(prompt_bufnr)
    end,
  },
  {
    key = "<C-r>",
    desc = "Revert the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.revert_commit(commit_hash)
      actions.close(prompt_bufnr)
    end,
  },
  {
    key = "<C-p>",
    desc = "Cherry-pick the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.cherry_pick_commit(commit_hash)
      actions.close(prompt_bufnr)
    end,
  },
  {
    key = "<C-d>",
    desc = "Show the diff of the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.show_diff(commit_hash)
    end,
  },
  {
    key = "<C-y>",
    desc = "Copy the commit hash to clipboard",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.copy_commit_hash(commit_hash)
    end,
  },
  {
    key = "<C-o>",
    desc = "Open the commit in the browser (GitHub)",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.open_in_browser(commit_hash)
    end,
  },
  {
    key = "<C-t>",
    desc = "Tag the selected commit",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      local tag_name = vim.fn.input("Tag name: ")
      commit_actions.tag_commit(commit_hash, tag_name)
    end,
  },
  {
    key = "<C-c>",
    desc = "Compare the selected commit with HEAD",
    action = function(prompt_bufnr)
      local commit_hash = action_state.get_selected_entry().value
      commit_actions.compare_with_head(commit_hash)
    end,
  },
  {
    key = "<C-h>",
    desc = "Show this help",
    action = function(prompt_bufnr)
      local picker = action_state.get_current_picker(prompt_bufnr)
      local previewer = picker.previewer
      M.show_help(previewer) -- Correctly reference M.show_help
    end,
  },
}

-- Generate commit_keymaps and action_map dynamically
M.commit_keymaps = vim.tbl_map(function(item)
  return { key = item.key, desc = item.desc }
end, base_keymaps)

M.action_map = vim.tbl_map(function(item)
  return { [item.desc] = item.action }
end, base_keymaps)

-- Flatten action_map for easier access
M.action_map = vim.tbl_extend("force", unpack(M.action_map))

-- Show keymaps in the previewer
function M.show_help(previewer)
  local help_lines = { "Keymaps:", "" }
  for _, keymap in ipairs(M.commit_keymaps) do
    table.insert(help_lines, string.format("%-6s - %s", keymap.key, keymap.desc))
  end
  vim.api.nvim_buf_set_lines(previewer.state.bufnr, 0, -1, false, help_lines)
end

M.commit_picker_keymaps = {
  {
    key = "<CR>",
    desc = "Select the commit",
    action = function(prompt_bufnr)
      local selection = require("telescope.actions.state").get_selected_entry()
      require("telescope.actions").close(prompt_bufnr)
      require("gitwiz.actions.commit_actions").select_commit(selection.value.hash)
    end,
  },
  {
    key = "<C-p>",
    desc = "Cherry-pick the selected commit",
    action = function(prompt_bufnr)
      local selection = require("telescope.actions.state").get_selected_entry()
      require("telescope.actions").close(prompt_bufnr)
      require("gitwiz.actions.commit_actions").cherry_pick_commit(selection.value.hash)
    end,
  },
}
return M
