
-- graph/state.lua
local M = {
  view_mode = "ascii", -- ascii | matrix | compact
  matrix = {
    sort_key = "branch",
    sort_dir = 1,         -- 1 asc, -1 desc (toggle not yet exposed)
    filter_pattern = nil, -- raw pattern string
    regex = nil,          -- compiled regex
  },
  compact = {
    folds = {},           -- line_index -> { expanded=false, hashes={...}, text="…(N linear commits)" }
    expanded_all = false,
  },
}

function M.rotate_view()
  if M.view_mode == "ascii" then
    M.view_mode = "matrix"
  elseif M.view_mode == "matrix" then
    M.view_mode = "compact"
  else
    M.view_mode = "ascii"
  end
end

function M.set_matrix_filter(pat)
  if not pat or pat == "" then
    M.matrix.filter_pattern = nil
    M.matrix.regex = nil
    return
  end
  M.matrix.filter_pattern = pat
  local ok, rx = pcall(vim.regex, pat)
  if ok then
    M.matrix.regex = rx
  else
    M.matrix.regex = nil
  end
end

function M.clear_matrix_filter()
  M.set_matrix_filter(nil)
end

function M.set_matrix_sort(key)
  if M.matrix.sort_key == key then
    -- toggle direction
    M.matrix.sort_dir = -M.matrix.sort_dir
  else
    M.matrix.sort_key = key
    M.matrix.sort_dir = 1
  end
end

-- Compact fold helpers
function M.compact_reset()
  M.compact.folds = {}
  M.compact.expanded_all = false
end

function M.compact_toggle_line(idx)
  local f = M.compact.folds[idx]
  if f then
    f.expanded = not f.expanded
  end
end

function M.compact_expand_all()
  for _, f in pairs(M.compact.folds) do f.expanded = true end
  M.compact.expanded_all = true
end

function M.compact_collapse_all()
  for _, f in pairs(M.compact.folds) do f.expanded = false end
  M.compact.expanded_all = false
end

return M
