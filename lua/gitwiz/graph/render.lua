-- graph/render.lua (ensure state module required before use)
local layout = require("gitwiz.graph.layout")
local runner = require("gitwiz.core.runner")
local config = require("gitwiz.core.config")
local build_ascii = require("gitwiz.graph.build")
local ascii_hl = require("gitwiz.graph.ascii")
local state = require("gitwiz.graph.state") -- ADDED (fix nil 'state' reference)
local matrix_mode = require("gitwiz.graph.modes.matrix")
local compact_mode = require("gitwiz.graph.modes.compact")

local M = {}

M.model = {
  groups = {},
  order = {},
  primary = nil,
  selected_group_index = 1,
  selected_branch_index = 1,
  filters = {
    merged = false,
    unmerged = false,
    stale = false,
  },
}

-- Added: force_next flag + public function used by actions.lua
local force_next = false
function M.force_refresh_next()
  force_next = true
end

local function set_lines(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local was_mod = vim.api.nvim_buf_get_option(buf, "modifiable")
  if not was_mod then vim.api.nvim_buf_set_option(buf, "modifiable", true) end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  if not was_mod then vim.api.nvim_buf_set_option(buf, "modifiable", false) end
end

local function sorted_keys(tbl)
  local keys = {}
  for k in pairs(tbl) do keys[#keys+1] = k end
  table.sort(keys)
  return keys
end

function M.set_data(primary, groups)
  M.model.groups = {}
  M.model.order = sorted_keys(groups)
  M.model.primary = primary
  for _, g in ipairs(M.model.order) do
    local copy = vim.deepcopy(groups[g])
    copy.open = true
    table.sort(copy.branches, function(a,b) return a.name < b.name end)
    M.model.groups[g] = copy
  end
  M.model.selected_group_index = 1
  M.model.selected_branch_index = 1
end

local function branch_passes_filters(br)
  local f = M.model.filters
  if f.merged and not br.merged then return false end
  if f.unmerged and br.merged then return false end
  if f.stale and not br.stale then return false end
  return true
end

function M.current_branch()
  local gname = M.model.order[M.model.selected_group_index]
  if not gname then return nil end
  local group = M.model.groups[gname]
  if not group.open then return nil end
  local idx = M.model.selected_branch_index
  local i = 0
  for _, br in ipairs(group.branches) do
    if branch_passes_filters(br) then
      i = i + 1
      if i == idx then return br end
    end
  end
  return nil
end

local function symbol_branch(branch)
  if branch.is_head then return "★"
  elseif branch.merged then return "✔"
  elseif branch.stale then return "⌛"
  elseif branch.ahead > 0 then return "⇡"
  elseif branch.behind > 0 then return "⇣"
  else return "⋄" end
end

local function group_line(gname, group, selected)
  local icon = group.open and "▼" or "▶"
  local count_total = #group.branches
  local count_filtered = 0
  for _, b in ipairs(group.branches) do
    if branch_passes_filters(b) then count_filtered = count_filtered + 1 end
  end
  local sel = selected and "➜" or " "
  return string.format("%s %s %s (%d/%d)", sel, icon, gname, count_filtered, count_total)
end

local function branch_line(branch, selected)
  if not branch_passes_filters(branch) then return nil end
  local sel = selected and "➜" or " "
  local sym = symbol_branch(branch)
  return string.format("  %s %s %-26s a:%d b:%d%s",
    sel, sym, branch.name, branch.ahead, branch.behind,
    branch.stale and " [stale]" or "")
end

local function count_display()
  local merged, unmerged, stale = 0,0,0
  local total = 0
  for _, gname in ipairs(M.model.order) do
    local grp = M.model.groups[gname]
    for _, b in ipairs(grp.branches) do
      total = total + 1
      if b.merged then merged = merged + 1 else unmerged = unmerged + 1 end
      if b.stale then stale = stale + 1 end
    end
  end
  return string.format("Total:%d merged:%d active:%d stale:%d", total, merged, unmerged, stale)
end

function M.render_tree()
  local buf = layout.state.buf.tree
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local lines = {}
  lines[#lines+1] = ("Primary: " .. (M.model.primary or "?"))
  lines[#lines+1] = count_display()
  lines[#lines+1] = string.format("Filters: %s%s%s",
    M.model.filters.merged and "[merged]" or "",
    M.model.filters.unmerged and "[unmerged]" or "",
    M.model.filters.stale and "[stale]" or "")
  lines[#lines+1] = string.rep("-", 30)
  for gi, gname in ipairs(M.model.order) do
    local group = M.model.groups[gname]
    lines[#lines+1] = group_line(gname, group,
      gi == M.model.selected_group_index and M.model.selected_branch_index == 0)
    if group.open then
      local i = 0
      for _, br in ipairs(group.branches) do
        if branch_passes_filters(br) then
          i = i + 1
          local selected = (gi == M.model.selected_group_index and M.model.selected_branch_index == i)
          local ln = branch_line(br, selected)
          if ln then lines[#lines+1] = ln end
        end
      end
    end
  end
  if config.get().graph.show_legend then
    lines[#lines+1] = ""
    lines[#lines+1] = "Legend: ★ HEAD  ✔ merged  ⇡ ahead  ⇣ behind  ⌛ stale  ⋄ clean"
    lines[#lines+1] = "Keys: j/k nav  <CR>/c checkout  l/h toggle  f filters"
    lines[#lines+1] = "      dd delete  D force-del  r/g refresh  q quit"
  end
  set_lines(buf, lines)
end

local function commit_sample_lines(branch)
  if not branch then return { "(no branch selected)" } end
  local hdr = string.format("Branch: %s %s", branch.name, branch.is_head and "(HEAD)" or "")
  local meta = {
    ("Ahead/Behind: %d/%d"):format(branch.ahead, branch.behind),
    "Merged: " .. tostring(branch.merged),
    "Stale: " .. tostring(branch.stale),
    "Updated: " .. (branch.updated or ""),
    "Base:    " .. (branch.base_info or "(none)"),
    "Tip:     " .. (branch.tip_info or "(none)"),
  }
  local lines = { hdr }
  for _, m in ipairs(meta) do lines[#lines+1] = m end
  lines[#lines+1] = string.rep("-", 60)
  lines[#lines+1] = "Recent commits:"
  for _, c in ipairs(branch.sample or {}) do lines[#lines+1] = "  " .. c end
  if #(branch.sample or {}) == 0 then lines[#lines+1] = "  (none)" end
  return lines
end

function M.render_info()
  local buf = layout.state.buf.info
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local lines = commit_sample_lines(M.current_branch())
  set_lines(buf, lines)
end

-- updated render_graph: store lane meta + colors for highlight
local build = require("gitwiz.graph.build")
local ascii_hl = require("gitwiz.graph.ascii")

local ascii_cache = { lines=nil, legend=nil, meta=nil, branch_colors=nil }

local function ascii_refresh()
  local r = build_ascii.build({})
  if not r.ok then
    ascii_cache.lines = { "Graph build error: " .. (r.error or "") }
    ascii_cache.legend = {}
    ascii_cache.meta = {}
    ascii_cache.branch_colors = {}
    return
  end
  ascii_cache.lines = r.lines
  ascii_cache.legend = r.legend
  ascii_cache.meta = r.lane_meta
  ascii_cache.branch_colors = r.branch_colors
end

function M.render_graph(data)
  local buf = layout.state.buf.graph
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  local mode = state.view_mode

  if mode == "ascii" then
    if force_next or not ascii_cache.lines then
      ascii_refresh()
      force_next = false
    end
    local cfg = config.get().graph
    local lines = {}
    lines[#lines+1] = "[Vista: ASCII] (gV rotate) Global Graph (max " .. (cfg.max_commits_global or 0) .. ")"
    lines[#lines+1] = string.rep("=", 60)
    for _, l in ipairs(ascii_cache.lines or {}) do lines[#lines+1] = l end
    lines[#lines+1] = ""
    for _, l in ipairs(ascii_cache.legend or {}) do lines[#lines+1] = l end
    lines[#lines+1] = "Modo:" .. (cfg.labels_mode or "?") .. "  Focus (pend)  Hints: gV rotate"
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    -- highlight
    local header_offset = 2
    local combined = {}
    for i,m in ipairs(ascii_cache.meta or {}) do
      combined[header_offset + i] = m
    end
    ascii_hl.apply(buf, lines, combined, ascii_cache.branch_colors)
    return
  elseif mode == "matrix" then
    local lines = matrix_mode.build(data)
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    return
  else -- compact
    local lines, commits = compact_mode.build(config.get().graph.max_commits_global or 400)
    local final = {}
    for idx, l in ipairs(lines) do
      final[#final+1] = l
      local fold = state.compact.folds[idx]
      if fold and fold.expanded then
        local extra = compact_mode.expand_line(idx, commits)
        for _, el in ipairs(extra) do final[#final+1] = el end
      end
    end
    table.insert(final, 1, "Keys: gV rotate  z/<CR> toggle fold  E expand all  C collapse all  (modo compact)")
    table.insert(final, 1, "[Vista: COMPACT] (collapsing linear chains)")
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, final)
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    return
  end
end

function M.refresh_all(data)
  M.render_tree()
  M.render_graph(data or { groups = {}, primary = "" })
  M.render_info()
end

local function visible_branch_count(group)
  local c = 0
  for _, b in ipairs(group.branches) do
    if branch_passes_filters(b) then c = c + 1 end
  end
  return c
end

function M.select_next()
  local gname = M.model.order[M.model.selected_group_index]
  if not gname then return end
  local group = M.model.groups[gname]
  if group.open then
    local total = visible_branch_count(group)
    if total > 0 and M.model.selected_branch_index < total then
      M.model.selected_branch_index = M.model.selected_branch_index + 1
      return
    end
  end
  if M.model.selected_group_index < #M.model.order then
    M.model.selected_group_index = M.model.selected_group_index + 1
    local ng = M.model.groups[M.model.order[M.model.selected_group_index]]
    M.model.selected_branch_index = ng.open and math.min(1, visible_branch_count(ng)) or 0
  end
end

function M.select_prev()
  local gname = M.model.order[M.model.selected_group_index]
  if not gname then return end
  if M.model.selected_branch_index > 1 then
    M.model.selected_branch_index = M.model.selected_branch_index - 1
    return
  end
  if M.model.selected_group_index > 1 then
    M.model.selected_group_index = M.model.selected_group_index - 1
    local pg = M.model.groups[M.model.order[M.model.selected_group_index]]
    if pg.open then
      local total = visible_branch_count(pg)
      M.model.selected_branch_index = total
    else
      M.model.selected_branch_index = 0
    end
  end
end

function M.toggle_group()
  local gname = M.model.order[M.model.selected_group_index]
  if not gname then return end
  local group = M.model.groups[gname]
  group.open = not group.open
  if not group.open then
    M.model.selected_branch_index = 0
  else
    M.model.selected_branch_index = math.min(1, visible_branch_count(group))
  end
end

function M.cycle_filters()
  local f = M.model.filters
  if not f.merged and not f.unmerged and not f.stale then
    f.merged = true
  elseif f.merged then
    f.merged = false; f.unmerged = true
  elseif f.unmerged then
    f.unmerged = false; f.stale = true
  else
    f.stale = false
  end
  M.model.selected_branch_index = 1
end

return M
