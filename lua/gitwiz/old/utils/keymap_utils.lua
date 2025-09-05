
local debug = require("gitwiz.config.debug")
local M = {}

-- Generate attach_mappings dynamically from keymaps
function M.generate_attach_mappings(keymaps)
  return function(_, map)
    for _, keymap in ipairs(keymaps) do
      map("i", keymap.key, keymap.action)
    end
    return true
  end
end

return M
