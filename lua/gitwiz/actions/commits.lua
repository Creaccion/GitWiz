-- actions/commits.lua (add revert + revert_many)
local runner = require("gitwiz.core.runner")
local events = require("gitwiz.core.events")
local log = require("gitwiz.log")

local M = {}

local function list_conflicts()
  local r = runner.run({ "diff", "--name-only", "--diff-filter=U" })
  if not r.ok then
    return {}
  end
  return r.stdout_lines
end

--- Cherry-pick a single commit.
-- @param hash string
function M.cherry_pick(hash)
  if not hash or hash == "" then
    return { ok = false, error = { reason = "invalid_arg", message = "Empty hash" } }
  end
  events.emit("cherry_pick:start", { hash = hash })
  local r = runner.run({ "cherry-pick", hash })
  if r.ok then
    log.info("Cherry-pick success: " .. hash)
    events.emit("cherry_pick:success", { hash = hash })
    events.emit("cherry_pick:done", { applied = { hash } })
    return { ok = true, data = { applied = { hash } } }
  end
  local conflicts = list_conflicts()
  if #conflicts > 0 then
    log.warn("Conflicts during cherry-pick: " .. hash)
    events.emit("cherry_pick:conflict", { hash = hash, conflicts = conflicts })
    return {
      ok = false,
      error = { reason = "conflicts", message = "Conflicts detected", details = conflicts },
    }
  end
  events.emit("cherry_pick:error", { hash = hash, stderr = r.stderr })
  return {
    ok = false,
    error = { reason = "git_error", message = "Cherry-pick failed", details = r.stderr },
  }
end

--- Cherry-pick multiple commits.
-- order = "chronological" oldest->newest; "selection" as provided
function M.cherry_pick_many(hashes, opts)
  if not hashes or #hashes == 0 then
    return { ok = false, error = { reason = "invalid_arg", message = "No hashes" } }
  end
  opts = opts or {}
  local order = opts.order or "chronological"

  local sequence = {}
  if order == "chronological" then
    for i = #hashes, 1, -1 do
      sequence[#sequence+1] = hashes[i]
    end
  else
    for i, h in ipairs(hashes) do sequence[i] = h end
  end

  local applied = {}
  local total = #sequence
  for idx, h in ipairs(sequence) do
    local res = M.cherry_pick(h)
    if not res.ok then
      return {
        ok = false,
        error = res.error,
        data = { applied = applied, last = h },
      }
    end
    applied[#applied+1] = h
    events.emit("cherry_pick:applied", { hash = h, index = idx, total = total })
  end
  events.emit("cherry_pick:done", { applied = applied })
  return { ok = true, data = { applied = applied } }
end

---------------------------------------------------------------------
-- Revert support
---------------------------------------------------------------------

--- Revert a single commit (creates a new commit).
-- @param hash string
-- @return table
function M.revert(hash)
  if not hash or hash == "" then
    return { ok = false, error = { reason = "invalid_arg", message = "Empty hash" } }
  end
  events.emit("revert:start", { hash = hash })
  local r = runner.run({ "revert", "--no-edit", hash })
  if r.ok then
    log.info("Revert success: " .. hash)
    events.emit("revert:success", { hash = hash })
    events.emit("revert:done", { reverted = { hash } })
    return { ok = true, data = { reverted = { hash } } }
  end
  local conflicts = list_conflicts()
  if #conflicts > 0 then
    log.warn("Conflicts during revert: " .. hash)
    events.emit("revert:conflict", { hash = hash, conflicts = conflicts })
    return {
      ok = false,
      error = { reason = "conflicts", message = "Conflicts detected", details = conflicts },
    }
  end
  events.emit("revert:error", { hash = hash, stderr = r.stderr })
  return {
    ok = false,
    error = { reason = "git_error", message = "Revert failed", details = r.stderr },
  }
end

--- Revert multiple commits.
-- Default order = "reverse": newest->oldest (safer typical sequence).
-- order="chronological": oldest->newest.
-- @param hashes string[]
-- @param opts table|nil { order="reverse"|"chronological" }
function M.revert_many(hashes, opts)
  if not hashes or #hashes == 0 then
    return { ok = false, error = { reason = "invalid_arg", message = "No hashes" } }
  end
  opts = opts or {}
  local order = opts.order or "reverse"

  local sequence = {}
  if order == "chronological" then
    for i = 1, #hashes do sequence[#sequence+1] = hashes[i] end
  else -- reverse (newest first)
    for i = 1, #hashes do sequence[i] = hashes[i] end
  end

  local reverted = {}
  local total = #sequence
  for idx, h in ipairs(sequence) do
    local res = M.revert(h)
    if not res.ok then
      return {
        ok = false,
        error = res.error,
        data = { reverted = reverted, last = h },
      }
    end
    reverted[#reverted+1] = h
    events.emit("revert:applied", { hash = h, index = idx, total = total })
  end
  events.emit("revert:done", { reverted = reverted })
  return { ok = true, data = { reverted = reverted } }
end

function M.cherry_pick_continue()
  local r = runner.run({ "cherry-pick", "--continue" })
  if r.ok then
    events.emit("cherry_pick:continue", {})
    events.emit("cherry_pick:done", { continued = true })
    return { ok = true }
  end
  return { ok = false, error = { reason = "git_error", message = "Continue failed", details = r.stderr } }
end

function M.cherry_pick_abort()
  local r = runner.run({ "cherry-pick", "--abort" })
  if r.ok then
    events.emit("cherry_pick:abort", {})
    return { ok = true }
  end
  return { ok = false, error = { reason = "git_error", message = "Abort failed", details = r.stderr } }
end

function M.cherry_pick_skip()
  local r = runner.run({ "cherry-pick", "--skip" })
  if r.ok then
    events.emit("cherry_pick:skip", {})
    return { ok = true }
  end
  return { ok = false, error = { reason = "git_error", message = "Skip failed", details = r.stderr } }
end
return M
