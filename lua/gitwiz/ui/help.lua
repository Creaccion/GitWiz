local M = {}
local debug = require("gitwiz.config.debug")

function M.show_help(keymaps)
  local help_lines = { "Keymaps:" }
  table.insert(help_lines, "")

  for _, keymap in ipairs(keymaps) do
    table.insert(help_lines, string.format("%-6s - %s", keymap.key, keymap.desc))
  end

  -- Create a floating window
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, help_lines)

  local width = vim.o.columns
  local height = vim.o.lines
  local win_width = math.floor(width * 0.5)
  local win_height = math.floor(height * 0.4)
  local row = math.floor((height - win_height) / 2)
  local col = math.floor((width - win_width) / 2)

  local opts = {
    style = "minimal",
    relative = "editor",
    width = win_width,
    height = win_height,
    row = row,
    col = col,
    border = "rounded",
    focusable = false, -- Prevent the window from taking focus
  }

  local win = vim.api.nvim_open_win(buf, false, opts) -- Set focus to false

  -- Close the window with <Esc>
  vim.api.nvim_buf_set_keymap(buf, "n", "<Esc>", "", {
    noremap = true,
    silent = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
    end,
  })

  -- Set the buffer as non-modifiable
  vim.api.nvim_buf_set_option(buf, "modifiable", false)

  -- Prevent <Esc> from propagating to other windows
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = buf,
    callback = function()
      if vim.api.nvim_buf_is_valid(buf) then
        vim.api.nvim_buf_delete(buf, { force = true })
      end
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })
end

return M
