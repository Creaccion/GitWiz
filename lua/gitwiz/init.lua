-- Entry point for GitWiz plugin
local M = {}

-- Register main commands here
function M.setup()
  -- Command to list Git branches using Telescope
  vim.api.nvim_create_user_command(
    "GitWizBranches",
    function()
      require("gitwiz.telescope").list_branches()
    end,
    { desc = "List Git branches with GitWiz" }
  )
end

return M

