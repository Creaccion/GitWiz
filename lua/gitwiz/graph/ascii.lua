-- graph/ascii.lua (per-lane coloring + merge connector highlights)
local M = {}
local NS = vim.api.nvim_create_namespace("gitwiz_graph_ascii")

local function ensure_hl()
  local function ensure(name, def)
    local ok = pcall(vim.api.nvim_get_hl, 0, { name = name })
    if not ok then vim.api.nvim_set_hl(0, name, def) end
  end
  ensure("GitWizGraphHead",  { link = "Identifier" })
  ensure("GitWizGraphMerge", { link = "Special" })
  ensure("GitWizGraphBirth", { link = "Label" })
  ensure("GitWizGraphRef",   { link = "Title" })
  ensure("GitWizGraphCommit",{ link = "Normal" })
  ensure("GitWizGraphLane",  { link = "Comment" })
  ensure("GitWizGraphConnector",{ link = "Statement" })
  local palette = {
    "DiffAdd","DiffChange","DiffDelete","String","Function","Type","Number",
    "Keyword","Boolean","Constant","PreProc","Identifier"
  }
  for i, grp in ipairs(palette) do
    ensure("GitWizGraphLaneColor"..i, { link = grp })
  end
  ensure("GitWizGraphLaneColor0", { link = "GitWizGraphLane" })
end

-- lane columns: pattern "X space" repeated. Column start indices for lane i: (i-1)*2
local function highlight_lanes(buf, line, row, lane_meta, branch_colors)
  for i, cell in ipairs(lane_meta) do
    local start_col = (i - 1) * 2
    local hl
    if cell.ch == "★" then
      hl = "GitWizGraphHead"
    elseif cell.ch == "" then
      hl = "GitWizGraphMerge"
    elseif cell.ch == "◜" then
      hl = "GitWizGraphBirth"
    elseif cell.ch == "╱" or cell.ch == "╲" then
      hl = "GitWizGraphConnector"
    elseif cell.is_node then
      -- node adopt lane color if owner known
      if cell.branch and branch_colors[cell.branch] then
        hl = "GitWizGraphLaneColor" .. branch_colors[cell.branch]
      else
        hl = "GitWizGraphCommit"
      end
    else
      -- vertical lane
      if cell.branch and branch_colors[cell.branch] and cell.ch == "│" then
        hl = "GitWizGraphLaneColor" .. branch_colors[cell.branch]
      else
        hl = "GitWizGraphLane"
      end
    end
    vim.api.nvim_buf_add_highlight(buf, NS, hl, row, start_col, start_col + 1)
  end
end

local function highlight_refs(buf, line, row)
  local s_ref = line:find("%(")
  if s_ref then
    local e_ref = line:find("%)%s*$")
    if e_ref then
      vim.api.nvim_buf_add_highlight(buf, NS, "GitWizGraphRef", row, s_ref - 1, e_ref)
    end
  end
end

function M.apply(buf, lines, meta, branch_colors)
  ensure_hl()
  vim.api.nvim_buf_clear_namespace(buf, NS, 0, -1)
  for i, line in ipairs(lines) do
    local row = i - 1
    local lane_region = line:match("^([^\t]*%s%s)")
    local lane_meta = meta[i]
    if lane_meta then
      highlight_lanes(buf, line, row, lane_meta, branch_colors or {})
    end
    highlight_refs(buf, line, row)
  end
end

return M
