-- conflicts/parser.lua (marker parsing + transformations)
local M = {}

-- Structure of a conflict block:
-- {
--   start_idx = line_number_of_<<<<<<< (1-based),
--   mid_idx = line_number_of_=======,
--   end_idx = line_number_of_>>>>>>>,
--   ours = { ... },
--   theirs = { ... },
--   marker_ours = line text of <<<<<<<,
--   marker_sep = line text of =======,
--   marker_theirs = line text of >>>>>>>>
-- }

function M.parse(lines)
  local blocks = {}
  local i = 1
  while i <= #lines do
    local line = lines[i]
    if line:match("^<<<<<<<") then
      local start_idx = i
      i = i + 1
      local ours = {}
      while i <= #lines and not lines[i]:match("^=======") do
        ours[#ours+1] = lines[i]
        i = i + 1
      end
      if i > #lines or not lines[i]:match("^=======") then
        -- malformed, abort
        break
      end
      local mid_idx = i
      i = i + 1
      local theirs = {}
      while i <= #lines and not lines[i]:match("^>>>>>>>") do
        theirs[#theirs+1] = lines[i]
        i = i + 1
      end
      if i > #lines or not lines[i]:match("^>>>>>>>") then
        -- malformed
        break
      end
      local end_idx = i
      blocks[#blocks+1] = {
        start_idx = start_idx,
        mid_idx = mid_idx,
        end_idx = end_idx,
        ours = ours,
        theirs = theirs,
        marker_ours = lines[start_idx],
        marker_sep = lines[mid_idx],
        marker_theirs = lines[end_idx],
      }
    end
    i = i + 1
  end
  return blocks
end

-- Keep both (ours then separator then theirs) without git markers.
function M.keep_both_transform(lines, separator)
  local blocks = M.parse(lines)
  if #blocks == 0 then
    return lines, 0
  end
  local out = {}
  local cursor = 1
  for _, b in ipairs(blocks) do
    -- copy before block
    while cursor < b.start_idx do
      out[#out+1] = lines[cursor]
      cursor = cursor + 1
    end
    -- replace block
    for _, l in ipairs(b.ours) do out[#out+1] = l end
    if separator and separator ~= "" then
      out[#out+1] = separator
    end
    for _, l in ipairs(b.theirs) do out[#out+1] = l end
    cursor = b.end_idx + 1
  end
  -- rest
  while cursor <= #lines do
    out[#out+1] = lines[cursor]
    cursor = cursor + 1
  end
  return out, #blocks
end

-- Remove only the marker lines, leaving merged content as-is (if user edited).
function M.clean_markers(lines)
  local out = {}
  local removed = 0
  for _, l in ipairs(lines) do
    if l:match("^<<<<<<<") or l:match("^=======") or l:match("^>>>>>>>") then
      removed = removed + 1
    else
      out[#out+1] = l
    end
  end
  return out, removed
end

return M
