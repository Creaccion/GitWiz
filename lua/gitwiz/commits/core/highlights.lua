-- commits/core/highlights.lua (add category highlight groups)
local M = {}
local NS = vim.api.nvim_create_namespace("gitwiz_commits_preview")

local defined = false

local function ensure(name, def)
  local ok = pcall(vim.api.nvim_get_hl, 0, { name = name })
  if not ok then vim.api.nvim_set_hl(0, name, def) end
end

function M.ensure_groups()
  if defined then return end
  ensure("GitWizMetaLabel", { link = "Identifier" })
  ensure("GitWizCommitHash", { link = "Title" })
  ensure("GitWizFileAdded", { link = "DiffAdd" })
  ensure("GitWizFileModified", { link = "DiffChange" })
  ensure("GitWizFileDeleted", { link = "DiffDelete" })
  ensure("GitWizFileRenamed", { link = "Directory" })
  ensure("GitWizHeader", { link = "Title" })
  ensure("GitWizDiffHunk", { link = "DiffText" })
  ensure("GitWizDiffAdd", { link = "DiffAdd" })
  ensure("GitWizDiffDel", { link = "DiffDelete" })
  ensure("GitWizLegend", { link = "Comment" })

  -- Nuevos para categorías
  ensure("GitWizCatAhead",  { link = "DiffAdd" })
  ensure("GitWizCatBehind", { link = "DiffDelete" })
  ensure("GitWizCatCommon", { link = "Identifier" })
  ensure("GitWizCatForeign",{ link = "Comment" })

  defined = true
end

function M.apply(bufnr, lines)
  M.ensure_groups()
  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  for i, l in ipairs(lines) do
    local idx = i - 1
    if l:match("^Summary:") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizHeader", idx, 0, -1)
    elseif l:match("^Legend:") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizLegend", idx, 0, -1)
    elseif l:match("^.+ Commit:%s+") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizCommitHash", idx, 0, -1)
    elseif l:match("^ Author:") or l:match("^ Date:") or l:match("^ Subject:") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizMetaLabel", idx, 0, 12)
    elseif l:match("^┌ Files") or l:match("^└") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizHeader", idx, 0, -1)
    elseif l:match("^diff %-%-git ") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizHeader", idx, 0, -1)
    elseif l:match("^@@") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizDiffHunk", idx, 0, -1)
    elseif l:match("^%+[^+]") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizDiffAdd", idx, 0, -1)
    elseif l:match("^%-[^-]") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizDiffDel", idx, 0, -1)
    elseif l:match("^%[Hints]") or l:match("^%[mode:") then
      vim.api.nvim_buf_add_highlight(bufnr, NS, "GitWizLegend", idx, 0, -1)
    end
  end
end

return M
