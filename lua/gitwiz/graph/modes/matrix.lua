
-- graph/modes/matrix.lua
local config = require("gitwiz.core.config")
local state = require("gitwiz.graph.state")

local M = {}

local function parse_iso(s)
  local y,m,d,H,Mn,S = s:match("^(%d%d%d%d)%-(%d%d)%-(%d%d)%s+(%d%d):(%d%d):(%d%d)")
  if not y then return 0 end
  return os.time({ year=y, month=m, day=d, hour=H, min=Mn, sec=S })
end

local function apply_filter(list)
  if not state.matrix.regex then return list end
  local out = {}
  for _, b in ipairs(list) do
    local text = b.name .. " " .. (b.tip_info or "") .. " " .. (b.base_info or "")
    if state.matrix.regex:match_str(text) then
      out[#out+1] = b
    end
  end
  return out
end

local sorters = {
  branch = function(a,b) return a.name < b.name end,
  ahead  = function(a,b) return a.ahead < b.ahead end,
  behind = function(a,b) return a.behind < b.behind end,
  updated= function(a,b) return parse_iso(a.updated) < parse_iso(b.updated) end,
  merged = function(a,b)
    if a.merged == b.merged then return a.name < b.name end
    return (not a.merged) and b.merged -- false after true places merged later
  end,
}

local function sort_branches(list)
  local key = state.matrix.sort_key or "branch"
  local cmp = sorters[key] or sorters.branch
  table.sort(list, function(x,y)
    local ok = cmp(x,y)
    if state.matrix.sort_dir == 1 then
      return ok
    else
      return not ok
    end
  end)
end

local function icon_head(b) return b.is_head and "★ " or "  " end

local function stale_icon(b)
  return b.stale and "⌛" or " "
end

local function merged_icon(b)
  return b.merged and "✔" or "✘"
end

local function pad(s, w)
  local l = vim.fn.strdisplaywidth(s)
  if l >= w then return s:sub(1, w) end
  return s .. string.rep(" ", w - l)
end

local function header()
  return {
    "[Vista: MATRIX] (gV rotate) Filter:" ..
      (state.matrix.filter_pattern or " <none>") ..
      " Sort:" .. state.matrix.sort_key .. (state.matrix.sort_dir==-1 and "↓" or "↑"),
    "Keys: gV rotate  s/a/b/u/m sort  / filter  R reset  <CR>/c checkout  dd delete  f filters merged/unmerged/stale",
    "┌" .. string.rep("─", 106) .. "┐",
    "│ Branch (★=HEAD)          | Ahd | Bhd | M | St | Updated           | Tip      | Subject                    │",
    "├" .. string.rep("─", 106) .. "┤",
  }
end

local function format_line(b)
  local name = icon_head(b) .. b.name
  name = pad(name, 26)
  local ahead = pad(tostring(b.ahead), 3)
  local behind = pad(tostring(b.behind),3)
  local merged = merged_icon(b)
  local stale = stale_icon(b)
  local updated = pad(b.updated or "", 19)
  local tip = pad((b.tip or ""):sub(1,8),8)
  local subj = pad((b.tip_info or ""):match("^%S+%s+(.+)$") or (b.tip_info or ""), 26)
  return string.format("│ %s | %s | %s | %s | %s | %s | %s | %s │",
    name, ahead, behind, merged, stale, updated, tip, subj)
end

local function footer(count)
  return {
    "└" .. string.rep("─", 106) .. "┘",
    ("Ramas mostradas: %d"):format(count)
  }
end

function M.build(data)
  local branches = {}
  for _, g in pairs(data.groups or {}) do
    for _, b in ipairs(g.branches) do
      branches[#branches+1] = b
    end
  end
  branches = apply_filter(branches)
  sort_branches(branches)
  local lines = header()
  for _, b in ipairs(branches) do
    lines[#lines+1] = format_line(b)
  end
  local f = footer(#branches)
  for _, l in ipairs(f) do lines[#lines+1] = l end
  return lines
end

return M
