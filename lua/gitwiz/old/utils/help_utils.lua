
local debug = require("gitwiz.config.debug")
local M = {}

-- Generate help lines dynamically from keymaps
function M.generate_help_lines(keymaps)
  local help_lines = {}
  for _, keymap in ipairs(keymaps) do
    table.insert(help_lines, string.format("  %s - %s", keymap.key, keymap.desc))
  end
  return help_lines
end

return M
