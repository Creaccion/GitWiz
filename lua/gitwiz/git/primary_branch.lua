-- git/primary_branch.lua (robust detection without noisy git failures)
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")

local M = {}
local cache = nil

local function run(args)
  local r = runner.run(args)
  if not r.ok then return nil end
  return r.stdout_lines
end

local function list_local_branches()
  local lines = run({ "for-each-ref", "--format=%(refname:short)", "refs/heads" }) or {}
  local set = {}
  for _, l in ipairs(lines) do
    if l ~= "" then set[l] = true end
  end
  return set
end

-- NEW: safe remote origin presence + file existence
local function origin_head()
  -- Check remote 'origin' exists
  local remotes = run({ "remote" }) or {}
  local has_origin = false
  for _, r in ipairs(remotes) do
    if r == "origin" then has_origin = true break end
  end
  if not has_origin then return nil end

  -- Check the ref file exists (avoid symbolic-ref call if missing)
  local path_lines = run({ "rev-parse", "--git-path", "refs/remotes/origin/HEAD" })
  if not path_lines or not path_lines[1] then return nil end
  local path = path_lines[1]
  local stat = vim.loop.fs_stat(path)
  if not stat then return nil end

  -- Now safely resolve
  local lines = run({ "symbolic-ref", "refs/remotes/origin/HEAD" })
  if not lines or not lines[1] then return nil end
  local ref = lines[1]
  local name = ref:match("refs/remotes/origin/(.+)$")
  return name
end

local function current_branch()
  local lines = run({ "symbolic-ref", "--quiet", "--short", "HEAD" })
  if lines and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return nil
end

local function first_existing_candidate(local_set, candidates)
  for _, c in ipairs(candidates) do
    if local_set[c] then
      return c, "candidate"
    end
  end
  return nil
end

local function newest_branch(local_set)
  local lines = run({
    "for-each-ref",
    "--sort=-committerdate",
    "--format=%(refname:short)",
    "refs/heads",
  })
  if not lines then return nil end
  for _, l in ipairs(lines) do
    if l ~= "" and local_set[l] then
      return l
    end
  end
  return nil
end

function M.detect(force)
  if cache and not force then return cache end
  local cfg = config.get()

  if cfg.primary_branch_override then
    cache = { name = cfg.primary_branch_override, source = "override" }
    return cache
  end

  local locals = list_local_branches()
  if next(locals) == nil then
    cache = { name = "HEAD", source = "empty" }
    return cache
  end

  local ohead = origin_head()
  if ohead and locals[ohead] then
    cache = { name = ohead, source = "origin_head" }
    return cache
  end

  local candidates = cfg.primary_branch_candidates or { "main", "master", "develop", "trunk" }
  local cand, src = first_existing_candidate(locals, candidates)
  if cand then
    cache = { name = cand, source = src }
    return cache
  end

  local cur = current_branch()
  if cur and locals[cur] then
    cache = { name = cur, source = "current" }
    return cache
  end

  local newest = newest_branch(locals)
  if newest then
    cache = { name = newest, source = "recent" }
    return cache
  end

  cache = { name = "HEAD", source = "fallback" }
  return cache
end

return M
