-- Entry point for GitWiz plugin
local M = {}

-- Register main commands for GitWiz
function M.setup()
  opts = opts or {}
  require("gitwiz.log").setup(opts.log or { level = "debug" })
  -- Command to list Git branches using Telescope
  vim.api.nvim_create_user_command(
    "GitWizBranches",
    function()
      require("gitwiz.telescope.branch").list_branches()
    end,
    { desc = "List Git branches with GitWiz" }
  )

  -- Command to create a new branch
  vim.api.nvim_create_user_command(
    "GitWizCreateBranch",
    function()
      require("gitwiz.telescope.branch").create_branch_picker()
    end,
    { desc = "Create a new Git branch with GitWiz" }
  )
end

-- Command to rename a branch
vim.api.nvim_create_user_command(
  "GitWizRenameBranch",
  function()
    require("gitwiz.telescope.branch").rename_branch_picker()
  end,
  { desc = "Rename a Git branch with GitWiz" }
)

-- Command to delete a branch
vim.api.nvim_create_user_command(
  "GitWizDeleteBranch",
  function()
    require("gitwiz.telescope.branch").delete_branch_picker()
  end,
  { desc = "Delete a Git branch with GitWiz" }
)

vim.api.nvim_create_user_command(
  "GitWizMergeBranch",
  function()
    require("gitwiz.telescope.branch").merge_branch_picker()
  end,
  { desc = "Merge a branch into the current branch with GitWiz" }
)

-- Command to start interactive rebase onto a branch
vim.api.nvim_create_user_command(
  "GitWizInteractiveRebase",
  function()
    require("gitwiz.telescope.branch").interactive_rebase_picker()
  end,
  { desc = "Start interactive rebase onto a branch with GitWiz" }
)

vim.api.nvim_create_user_command(
  "GitWizRebaseUI",
  function()
    require("gitwiz.buffer.rebase").open_rebase_ui()
  end,
  { desc = "Open GitWiz interactive rebase UI" }
)

vim.api.nvim_create_user_command(
  "GitWizListAllCommits",
  function()
    require("gitwiz.telescope.commit").list_all_commits_picker()
  end,
  { desc = "G itWiz: List All Commits" }
)
vim.api.nvim_create_user_command(
  "GitWizListCommits",
  function()
    require("gitwiz.telescope.commit").list_commits()
  end,
  { desc = "GitWiz: List Branch Commits" }
)

vim.api.nvim_create_user_command(
  "GitWizSearchCommits",
  function()
    require("gitwiz.telescope.commit").search_commits_picker()
  end, 
  { desc = "GitWiz: Search text in commit history" }
)

vim.api.nvim_create_user_command(
  "GitWizLiveSearchCommits",
  function()
    require("gitwiz.telescope.live_commit_search").SearchGitLogLive()
  end,
  { desc = "GitWiz: Live search in git commit history" }
)

vim.api.nvim_create_user_command(
  "GitWizLiveSearchCommits2",
  function()
    require("gitwiz.telescope.live_commit_search").live_commit_search_S()
  end,
  { desc = "GitWiz: Live search in git commit history" }
)


vim.api.nvim_create_autocmd("BufReadPost", {
  pattern = "git-rebase-todo",
  callback = function()
    require("gitwiz.buffer.rebase").enrich_rebase_buffer()
  end,
})

vim.api.nvim_create_user_command("GitWizStashes", function()
  require("gitwiz.telescope.stash").list_stashes()
end, {})

vim.api.nvim_create_user_command("GitWizTags", function()
  require("gitwiz.telescope.tag").list_tags()
end, {})

vim.api.nvim_create_user_command("GitWizRemotes", function()
  require("gitwiz.telescope.remote").list_remotes()
end, {})


vim.api.nvim_create_user_command(
  "GitWizCherryPick",
  function()
    require("gitwiz.telescope.commit").list_commits_with_cherry_pick()
  end,
  { desc = "GitWiz: Cherry-pick commit from picker" }
)
return M
