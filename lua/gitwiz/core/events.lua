-- core/events.lua (enhanced with subscription ids and management)
local log = require("gitwiz.log")

local M = {
  _subs = {},      -- eventName -> { { id=number, cb=function }, ... }
  _next_id = 1,
  _id_event = {},  -- id -> eventName
}

--- Subscribe to an event.
-- @param name string event name
-- @param cb function callback(payload)
-- @return number|nil id, function off() to unsubscribe
function M.on(name, cb)
  if type(cb) ~= "function" then
    return nil, function() end
  end
  local entry = { id = M._next_id, cb = cb }
  M._next_id = M._next_id + 1
  local list = M._subs[name]
  if not list then
    list = {}
    M._subs[name] = list
  end
  table.insert(list, entry)
  M._id_event[entry.id] = name
  local function off()
    M.off(entry.id)
  end
  return entry.id, off
end

--- Unsubscribe by id.
-- @param id number
function M.off(id)
  local name = M._id_event[id]
  if not name then return end
  local list = M._subs[name]
  if not list then return end
  for i, entry in ipairs(list) do
    if entry.id == id then
      table.remove(list, i)
      break
    end
  end
  M._id_event[id] = nil
  if #list == 0 then
    M._subs[name] = nil
  end
end

--- Clear all listeners of a specific event or all events if name is nil.
-- @param name string|nil
function M.clear(name)
  if name then
    local list = M._subs[name]
    if list then
      for _, entry in ipairs(list) do
        M._id_event[entry.id] = nil
      end
    end
    M._subs[name] = nil
  else
    for _, list in pairs(M._subs) do
      for _, entry in ipairs(list) do
        M._id_event[entry.id] = nil
      end
    end
    M._subs = {}
  end
end

--- Emit an event.
-- Safe-calls each handler. Copy list to avoid mutation issues.
-- @param name string
-- @param payload any
function M.emit(name, payload)
  local list = M._subs[name]
  if not list then return end
  -- shallow copy to avoid issues if handlers unsubscribe while iterating
  local snapshot = {}
  for i, v in ipairs(list) do
    snapshot[i] = v
  end
  for _, entry in ipairs(snapshot) do
    local ok, err = pcall(entry.cb, payload)
    if not ok then
      log.warn("Event handler error: " .. tostring(err))
    end
  end
end

return M
