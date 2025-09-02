-- Git actions for GitWiz (checkout, merge, diff, etc.)
local M = {}

-- Checkout the selected branch
function M.checkout_branch(branch)
  local cmd = string.format("git checkout %s", branch)
  -- To be implemented: Run git checkout <branch>
  local result = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    print("Checkout failed: " .. result)
  else
    print("Checked out to branch: " .. branch)
  end
end

return M

