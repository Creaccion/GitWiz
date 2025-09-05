
local M = {}
local store = {}

function M.get(key) return store[key] end
function M.set(key, value) store[key] = value end
function M.clear() store = {} end

function M.scoped_key(parts)
  return table.concat(parts, "|")
end

return M
