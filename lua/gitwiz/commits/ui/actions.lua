
-- commits/ui/actions.lua
local actions_commits = require("gitwiz.actions.commits")
local log = require("gitwiz.log")

local M = {}

local function cherry_pick_many(hashes)
  if #hashes == 1 then
    return actions_commits.cherry_pick(hashes[1])
  end
  return actions_commits.cherry_pick_many(hashes, { order = "chronological" })
end

local function revert_many(hashes)
  if #hashes == 1 then
    return actions_commits.revert(hashes[1])
  end
  return actions_commits.revert_many(hashes, { order = "reverse" })
end

function M.toggle(entries, refresh_cb)
  local to_add, to_remove = {}, {}
  for _, e in ipairs(entries) do
    if e.placeholder then
      -- skip
    elseif e.in_current then
      to_remove[#to_remove+1] = e.hash
    else
      to_add[#to_add+1] = e.hash
    end
  end
  if #to_remove > 0 then
    local r = revert_many(to_remove)
    if not r.ok then
      log.warn("Revert failed/partial: " .. (r.error.message or r.error.reason))
      refresh_cb()
      return
    else
      log.info("Reverted " .. #to_remove .. " commit(s)")
    end
  end
  if #to_add > 0 then
    local c = cherry_pick_many(to_add)
    if not c.ok then
      if c.error.reason == "conflicts" then
        log.warn("Cherry-pick conflict triggered")
      else
        log.warn("Cherry-pick failed: " .. (c.error.message or c.error.reason))
      end
      return
    else
      log.info("Cherry-picked " .. #to_add .. " commit(s)")
    end
  end
  refresh_cb()
end

function M.cherry_pick(entries, refresh_cb)
  local hashes = {}
  for _, e in ipairs(entries) do
    if not e.placeholder then
      hashes[#hashes+1] = e.hash
    end
  end
  if #hashes == 0 then
    log.warn("No real commits selected")
    return
  end
  local res = cherry_pick_many(hashes)
  if res.ok then
    log.info("Cherry-pick applied count=" .. #hashes)
    refresh_cb()
  else
    if res.error.reason == "conflicts" then
      log.warn("Conflicts detected (" .. #res.error.details .. " files)")
    else
      log.error("Cherry-pick failed: " .. (res.error.message or "error"))
      refresh_cb()
    end
  end
end

return M
