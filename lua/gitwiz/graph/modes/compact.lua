-- graph/modes/compact.lua
-- Simplified compact topology: collapse linear chains
local primary_branch = require("gitwiz.git.primary_branch")
local runner = require("gitwiz.core.runner")
local state = require("gitwiz.graph.state")

local M = {}

local function run(args)
  local r = runner.run(args)
  if not r.ok then return nil end
  return r.stdout_lines
end

local function load_raw(limit)
  local args = {
    "log",
    "--date-order",
    "--max-count=" .. tostring(limit),
    "--parents",
    "--pretty=%H%x1f%h%x1f%P%x1f%s",
    "--all",
  }
  local lines = run(args) or {}
  local commits = {}
  local index = {}
  for _, l in ipairs(lines) do
    if l ~= "" then
      local parts = {}
      for f in l:gmatch("([^\31]+)") do parts[#parts+1] = f end
      local full = parts[1]
      if full then
        local short = parts[2] or full:sub(1,7)
        local parents_raw = parts[3] or ""
        local subject = parts[4] or ""
        local parents = {}
        if parents_raw ~= "" then
          for p in parents_raw:gmatch("%S+") do parents[#parents+1] = p end
        end
        local c = {
          hash = full, short = short, parents = parents, subject = subject,
          children = {},
        }
        commits[#commits+1] = c
        index[full] = c
      end
    end
  end
  -- build children map
  for _, c in ipairs(commits) do
    for _, p in ipairs(c.parents) do
      local pc = index[p]
      if pc then
        pc.children[#pc.children+1] = c.hash
      end
    end
  end
  return commits, index
end

local function is_linear(c)
  return #c.parents == 1 and #c.children == 1
end

local function mark_keep(commits, index)
  local keep = {}
  for _, c in ipairs(commits) do
    if c.hash == commits[#commits].hash then
      keep[c.hash] = true -- top (most recent) keep
    elseif c.hash == commits[#commits].hash then
      keep[c.hash] = true
    end
    if #c.parents ~= 1 then keep[c.hash] = true end
    if #c.children ~= 1 then keep[c.hash] = true end
  end
  -- ensure first (oldest) and last (newest)
  if commits[1] then keep[commits[1].hash] = true end
  if commits[#commits] then keep[commits[#commits].hash] = true end
  return keep
end

local function build_blocks(commits, index, keep)
  local blocks = {}
  local i = 1
  while i <= #commits do
    local c = commits[i]
    if keep[c.hash] then
      blocks[#blocks+1] = { type="node", commit=c }
      i = i + 1
    else
      local start_i = i
      local count = 0
      while i <= #commits do
        local cc = commits[i]
        if keep[cc.hash] then break end
        count = count + 1
        i = i + 1
      end
      blocks[#blocks+1] = { type="fold", count=count, start_index=start_i, end_index=i-1 }
    end
  end
  return blocks
end

local function format_node(c)
  return string.format("● %s %s", c.short, c.subject)
end

local function format_fold(block)
  return string.format("…(%d linear commit%s)", block.count, block.count > 1 and "s" or "")
end

function M.build(limit)
  limit = limit or 400
  state.compact_reset()
  local commits, index = load_raw(limit)
  if #commits == 0 then
    return { "(no commits)" }
  end
  local keep = mark_keep(commits, index)
  local blocks = build_blocks(commits, index, keep)

  local lines = {}
  local line_nr = 1
  for _, b in ipairs(blocks) do
    if b.type == "node" then
      lines[#lines+1] = format_node(b.commit)
      line_nr = line_nr + 1
    else
      lines[#lines+1] = format_fold(b)
      state.compact.folds[#lines] = {
        expanded = false,
        start = b.start_index,
        count = b.count,
      }
      line_nr = line_nr + 1
    end
  end
  return lines, commits
end

function M.expand_line(line_idx, commits)
  local f = state.compact.folds[line_idx]
  if not f then return nil end
  local out = {}
  for i = f.start, f.start + f.count - 1 do
    local c = commits[i]
    out[#out+1] = "  " .. c.short .. " " .. c.subject
  end
  return out
end

return M

