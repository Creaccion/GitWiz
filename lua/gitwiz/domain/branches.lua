-- domain/branches.lua (HEAD, stale, optional remotes)
local runner = require("gitwiz.core.runner")
local primary_branch = require("gitwiz.git.primary_branch")
local config = require("gitwiz.core.config")

local M = {}

local function run(args) return runner.run(args) end

local function split_tab(line)
  local parts = {}
  for field in string.gmatch(line, "([^\t]+)") do
    parts[#parts+1] = field
  end
  return parts
end

local function current_branch_name()
  local r = run({ "symbolic-ref", "--quiet", "--short", "HEAD" })
  if r.ok and r.stdout_lines[1] then
    return r.stdout_lines[1]
  end
  return nil
end

local function list_refs(pattern)
  local r = run({
    "for-each-ref",
    "--format=%(refname:short)\t%(objectname)\t%(committerdate:iso8601)\t%(authorname)",
    pattern,
  })
  if not r.ok then return {} end
  local out = {}
  for _, l in ipairs(r.stdout_lines) do
    if l ~= "" then
      local p = split_tab(l)
      out[#out+1] = {
        name = p[1] or "",
        tip = p[2] or "",
        updated = p[3] or "",
        author = p[4] or "",
      }
    end
  end
  return out
end

local function list_local_refs()
  return list_refs("refs/heads")
end

local function list_remote_refs()
  return list_refs("refs/remotes")
end

local function branch_merged_map(primary_name)
  local r = run({ "branch", "--merged", primary_name })
  local merged = {}
  if r.ok then
    for _, l in ipairs(r.stdout_lines) do
      local bn = l:gsub("^%*%s*", ""):gsub("^%s*", ""):gsub("%s+$", "")
      if bn ~= "" then merged[bn] = true end
    end
  end
  return merged
end

local function ahead_behind(branch, primary_name)
  local r = run({ "rev-list", "--left-right", "--count", branch .. "..." .. primary_name })
  if not r.ok or not r.stdout_lines[1] then
    return 0, 0
  end
  local a, b = r.stdout_lines[1]:match("(%d+)%s+(%d+)")
  return tonumber(a) or 0, tonumber(b) or 0
end

local function branch_base(branch, primary_name)
  local r = run({ "merge-base", branch, primary_name })
  if r.ok and r.stdout_lines[1] then
    return r.stdout_lines[1]
  end
  return nil
end

local function short_subject(hash)
  if not hash or hash == "" then return "" end
  local r = run({ "show", "-s", "--pretty=%h %s", hash })
  if r.ok and r.stdout_lines[1] then
    return r.stdout_lines[1]
  end
  return ""
end

local function parse_iso8601(str)
  -- "2025-08-06 10:42:57 -0400"
  local y, m, d, H, M, S = str:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)")
  if not y then return nil end
  return os.time({ year = y, month = m, day = d, hour = H, min = M, sec = S })
end

local function collect(limit_commits_per_branch, include_groups)
  local cfg = config.get()
  local graph_cfg = cfg.graph
  local primary = primary_branch.detect()
  local primary_name = primary.name
  local head_name = current_branch_name()
  local refs = list_local_refs()

  if graph_cfg.include_remotes then
    local remotes = list_remote_refs()
    for _, r in ipairs(remotes) do
      -- skip origin/HEAD symbolic ref
      if not r.name:match("^origin/HEAD$") then
        refs[#refs+1] = r
      end
    end
  end

  local merged_map = branch_merged_map(primary_name)
  local now = os.time()
  local stale_secs = (graph_cfg.stale_days or 14) * 86400

  local branches = {}
  for _, br in ipairs(refs) do
    local a, b = ahead_behind(br.name, primary_name)
    local base = branch_base(br.name, primary_name)
    local ut = parse_iso8601(br.updated)
    local stale = false
    if ut and stale_secs > 0 then
      stale = (now - ut) > stale_secs
    end
    branches[#branches+1] = {
      name = br.name,
      tip = br.tip,
      updated = br.updated,
      author = br.author,
      ahead = a,
      behind = b,
      merged = merged_map[br.name] or false,
      base = base,
      base_info = short_subject(base),
      tip_info = short_subject(br.tip),
      is_head = (br.name == head_name),
      stale = stale,
      is_remote = br.name:match("^origin/"),
    }
  end

  if limit_commits_per_branch and limit_commits_per_branch > 0 then
    for _, b in ipairs(branches) do
      local rr = run({
        "log",
        b.name,
        "--pretty=%h %s",
        "-n", tostring(limit_commits_per_branch),
      })
      local list = {}
      if rr.ok then
        for _, l in ipairs(rr.stdout_lines) do
          if l ~= "" then list[#list+1] = l end
        end
      end
      b.sample = list
    end
  end

  local groups = {}
  if include_groups then
    for _, b in ipairs(branches) do
      local prefix = b.name:match("([^/]+)/") or "(root)"
      groups[prefix] = groups[prefix] or { name = prefix, branches = {} }
      table.insert(groups[prefix].branches, b)
    end
  end

  return {
    primary = primary_name,
    branches = branches,
    groups = groups,
  }
end

function M.list(opts)
  opts = opts or {}
  local data = collect(opts.limit_branch_commits or 5, true)
  return { ok = true, data = data }
end

return M
