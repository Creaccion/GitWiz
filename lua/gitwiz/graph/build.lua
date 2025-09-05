-- graph/build.lua (lane ownership coloring + minimal merge connector data)
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")
local primary_branch = require("gitwiz.git.primary_branch")

local M = {}

local function run(args)
  local r = runner.run(args)
  if not r.ok then return nil, r.stderr end
  return r.stdout_lines
end

local function load_commits(branch_names, limit)
  local args = {
    "log",
    "--date-order",
    "--max-count=" .. tostring(limit),
    "--parents",
    "--pretty=%H%x1f%h%x1f%P%x1f%s",
  }
  for _, b in ipairs(branch_names) do
    args[#args+1] = b
  end
  local lines, err = run(args)
  if not lines then return nil, err end
  local commits, index = {}, {}
  for _, l in ipairs(lines) do
    if l ~= "" then
      local parts = {}
      for f in l:gmatch("([^\31]+)") do parts[#parts+1] = f end
      local full = parts[1]
      local short = parts[2]
      local parents_raw = parts[3] or ""
      local subject = parts[4] or ""
      local parents = {}
      if parents_raw ~= "" then
        for p in parents_raw:gmatch("%S+") do parents[#parents+1] = p end
      end
      local c = {
        hash = full,
        short = short,
        parents = parents,
        subject = subject,
        refs = {},
        lane = nil,
        is_merge = (#parents > 1),
        is_head = false,
        is_tip = false,
        owners = {},
        birth_labels = {},
        parent_lanes = {},   -- lanes (indexes) for each parent after assignment step
      }
      commits[#commits+1] = c
      index[full] = c
    end
  end
  return commits, index
end

local function split_tab(line)
  local parts = {}
  for field in line:gmatch("([^\t]+)") do parts[#parts+1] = field end
  return parts
end

local function list_branch_tips(include_remotes)
  local tips = {}
  local locals = run({
    "for-each-ref",
    "--format=%(refname:short)\t%(objectname)",
    "refs/heads",
  }) or {}
  for _, l in ipairs(locals) do
    if l ~= "" then
      local p = split_tab(l)
      if p[1] and p[2] then
        tips[#tips+1] = { name = p[1], hash = p[2], remote = false }
      end
    end
  end
  if include_remotes then
    local remotes = run({
      "for-each-ref",
      "--format=%(refname:short)\t%(objectname)",
      "refs/remotes",
    }) or {}
    for _, l in ipairs(remotes) do
      if l ~= "" then
        local p = split_tab(l)
        if p[1] and p[2] and not p[1]:match("^origin/HEAD$") then
          tips[#tips+1] = { name = p[1], hash = p[2], remote = true }
        end
      end
    end
  end
  return tips
end

local function current_head()
  local lines = run({ "symbolic-ref", "--quiet", "--short", "HEAD" })
  if not lines or not lines[1] then return nil end
  return lines[1]
end

local function collect_exclusive(branch, primary_name, limit)
  local args = {
    "rev-list",
    "--max-count=" .. tostring(limit),
    branch,
    "^" .. primary_name,
  }
  local lines = run(args) or {}
  local set = {}
  for _, h in ipairs(lines) do
    if h ~= "" then set[h] = true end
  end
  return set
end

local function birth_commit(branch, primary_name)
  local lines = run({
    "rev-list",
    "--reverse",
    branch,
    "^" .. primary_name,
    "--max-count=1",
  })
  if lines and lines[1] and lines[1] ~= "" then
    return lines[1]
  end
  return nil
end

local function attach_refs(commits, index, include_remotes, show_refs_inline)
  local tips = list_branch_tips(include_remotes)
  local head_branch = current_head()
  local by_hash = {}
  for _, t in ipairs(tips) do
    by_hash[t.hash] = by_hash[t.hash] or {}
    table.insert(by_hash[t.hash], t.name)
  end
  for _, c in ipairs(commits) do
    local r = by_hash[c.hash]
    if r then
      c.refs = r
      c.is_tip = true
      if head_branch then
        for _, name in ipairs(r) do
          if name == head_branch then
            c.is_head = true
            break
          end
        end
      end
    end
  end
  return tips
end

-- Lane assignment (extended: record parent lanes after placement)
local function assign_lanes(commits)
  local lanes = {}
  local lane_index = {}

  for _, c in ipairs(commits) do
    local lane = lane_index[c.hash]
    if not lane then
      lane = #lanes + 1
      lanes[lane] = c.hash
      lane_index[c.hash] = lane
    end
    c.lane = lane

    if #c.parents == 0 then
      lanes[lane] = nil
    else
      -- First parent stays
      lanes[lane] = c.parents[1]
      lane_index[c.parents[1]] = lane
      c.parent_lanes[1] = lane
      -- Additional parents inserted
      for i = 2, #c.parents do
        local parent = c.parents[i]
        local inserted = false
        for pos = 1, #lanes do
          if not lanes[pos] then
            lanes[pos] = parent
            lane_index[parent] = pos
            c.parent_lanes[i] = pos
            inserted = true
            break
          end
        end
        if not inserted then
          lane_index[parent] = #lanes + 1
          lanes[#lanes+1] = parent
          c.parent_lanes[i] = #lanes
        end
      end
    end
  end
end

local function truncate_subject(s, maxlen)
  if #s <= maxlen then return s end
  return s:sub(1, maxlen - 1) .. "…"
end

-- Build lane color ownership
local function compute_lane_owners(commits)
  local lane_owner = {}
  for _, c in ipairs(commits) do
    if c.lane and not lane_owner[c.lane] then
      for br in pairs(c.owners) do
        lane_owner[c.lane] = br
        break
      end
    end
  end
  return lane_owner
end

local function assign_branch_colors(lane_owner, max_colors)
  local branch_colors = {}
  local used = 0
  for _, br in pairs(lane_owner) do
    if br and not branch_colors[br] then
      used = used + 1
      if used <= max_colors then
        branch_colors[br] = used
      else
        branch_colors[br] = 0
      end
    end
  end
  return branch_colors
end

-- Encode lane color markers by wrapping node symbol with markers (for highlight pass)
local function colorize_lane_cells(line_cells, lane_colors, lane_owner)
  -- lane_cells is array of single char symbols for each lane index
  -- We'll build parallel metadata string but easier: embed marker pairs
  -- Simpler approach: keep lane_cells raw; highlight later by column index.
  return line_cells
end

local function build_lines(commits, opts, lane_owner, branch_colors)
  local cfg = config.get().graph
  local show_refs = cfg.show_refs_inline and cfg.refs_parenthesis
  local mode_labels = cfg.labels_mode
  local birth_symbol = cfg.birth_symbol or "◜"
  local max_subject = cfg.subject_truncate or 48

  local max_lane = 0
  for _, c in ipairs(commits) do
    if c.lane and c.lane > max_lane then max_lane = c.lane end
  end

  local lines = {}
  local meta = {}  -- per-line lane meta: { {char, owner_branch, is_node, lane_index} }
  for _, c in ipairs(commits) do
    local lane_cells = {}
    local lane_meta = {}
    for i = 1, max_lane do
      local sym
      if i == c.lane then
        if c.is_head then sym = "★"
        elseif c.is_merge then sym = ""
        else sym = "●" end
      else
        sym = "│"
      end
      lane_cells[#lane_cells+1] = sym
      lane_meta[#lane_meta+1] = {
        ch = sym,
        lane = i,
        branch = lane_owner[i],
        is_node = (i == c.lane),
      }
    end

    -- merge connectors minimal: additional parents -> place small indicator at parent lane column
    if c.is_merge and #c.parent_lanes > 1 then
      for pi = 2, #c.parent_lanes do
        local pl = c.parent_lanes[pi]
        if pl and pl <= #lane_cells then
          -- Replace vertical with diagonal hint (choose direction)
            if pl < c.lane then
              lane_cells[pl] = "╱"
              lane_meta[pl].ch = "╱"
            elseif pl > c.lane then
              lane_cells[pl] = "╲"
              lane_meta[pl].ch = "╲"
            end
        end
      end
    end

    local labels_part = ""
    if mode_labels == "birth" and #c.birth_labels > 0 then
      labels_part = " " .. birth_symbol .. " (" .. table.concat(c.birth_labels, ",") .. ")"
    elseif show_refs and #c.refs > 0 then
      labels_part = " (" .. table.concat(c.refs, ",") .. ")"
    end

    local subj = truncate_subject(c.subject, max_subject)
    local line_text = table.concat(lane_cells, " ") .. "  " .. c.short .. " " .. subj .. labels_part
    lines[#lines+1] = line_text
    meta[#meta+1] = lane_meta
  end

  return lines, meta
end

function M.build(opts)
  opts = opts or {}
  local cfg = config.get().graph
  local include_remotes = cfg.include_remotes
  local max_commits = cfg.max_commits_global or 400
  local primary = primary_branch.detect()
  local primary_name = primary.name

  local tips = list_branch_tips(include_remotes)
  if #tips == 0 then
    return { ok = true, lines = { "(no branches found)" }, legend = {} }
  end
  local branch_names = {}
  for _, t in ipairs(tips) do branch_names[#branch_names+1] = t.name end

  local commits, index = load_commits(branch_names, max_commits)
  if not commits then
    return { ok = false, error = "log_failed" }
  end

  attach_refs(commits, index, include_remotes, cfg.show_refs_inline)

  local exclusive_sets = {}
  local birth_points = {}
  for _, t in ipairs(tips) do
    if t.name ~= primary_name then
      exclusive_sets[t.name] = collect_exclusive(t.name, primary_name, max_commits)
      birth_points[t.name] = birth_commit(t.name, primary_name)
    end
  end

  for br, set in pairs(exclusive_sets) do
    for h in pairs(set) do
      local c = index[h]
      if c then
        c.owners[br] = true
      end
    end
  end

  for br, h in pairs(birth_points) do
    if h then
      local c = index[h]
      if c then
        c.birth_labels[#c.birth_labels+1] = br
      end
    end
  end

  assign_lanes(commits)

  local lane_owner = compute_lane_owners(commits)
  local branch_colors = assign_branch_colors(lane_owner, cfg.lanes_colors_max or 12)

  local lines, meta = build_lines(commits, opts, lane_owner, branch_colors)

  local legend = {
    "Legend:",
    "★ HEAD  ● commit   merge  " .. (cfg.birth_symbol or "◜") .. " birth(branch)  ╱╲ merge connectors",
  }

  return {
    ok = true,
    lines = lines,
    legend = legend,
    lane_owner = lane_owner,
    branch_colors = branch_colors,
    lane_meta = meta,
  }
end

return M
