local M = {}

local function build_files_table(files, icons)
  if #files == 0 then
    return { "┌ Files (0)", "│  (no files)", "└" }
  end
  local lines = {}
  lines[#lines+1] = ("┌ Files (" .. #files .. ")")
  for _, f in ipairs(files) do
    lines[#lines+1] = string.format("│ %s %-5s %s", icons.file, f.status:sub(1,5), f.path)
  end
  lines[#lines+1] = "└"
  return lines
end

local function build_meta_lines(meta, icons)
  return {
    icons.commit .. " Commit:  " .. meta.hash,
    " Author:  " .. meta.author,
    " Date:    " .. meta.date .. (meta.rel_date ~= "" and (" (" .. meta.rel_date .. ")") or ""),
    " Subject: " .. meta.subject,
  }
end

local function build_diff_lines(diff, limit, icons, view_mode)
  local out = {}
  if view_mode ~= "files" and view_mode ~= "meta" then
    out[#out+1] = icons.diff .. " Diff (limit " .. limit .. ")"
    local ln = math.min(#diff, limit)
    for i = 1, ln do out[#out+1] = diff[i] end
    if #diff > limit then
      out[#out+1] = "... (truncated " .. (#diff - limit) .. " more lines)"
    end
    if #diff == 0 then out[#out+1] = "(no diff content)" end
  end
  return out
end

function M.build(details, view_mode, cfg, summary)
  local lines = {}
  if summary then
    local search_part = summary.search and (" | search:'" .. summary.search .. "'") or ""
    lines[#lines+1] = string.format(
      "Summary: primary:%s | ahead:%d behind:%d foreign:%d common:%d total:%d | filter:%s%s",
      summary.primary or "?",
      summary.counts.ahead, summary.counts.behind, summary.counts.foreign,
      summary.counts.common, summary.counts.total, summary.filter, search_part
    )
    lines[#lines+1] = "Legend: ⇡ ahead  ⇣ behind  ✔ common  ⋄ foreign"
    lines[#lines+1] = "[keys: view:<Tab> | filters: ga gb gf gm g* | search: gs(grep) g/(clear) | toggle:<C-t> | cherry-pick:<C-p> | copy:<C-y>]"
    lines[#lines+1] = ""
  end
  local icons = cfg.commits.preview.icons
  local max_diff = cfg.commits.preview.max_diff_lines
  vim.list_extend(lines, build_meta_lines(details.meta, icons))
  if view_mode == "full" or view_mode == "files" then
    lines[#lines+1] = ""
    vim.list_extend(lines, build_files_table(details.files, icons))
  end
  if view_mode == "full" or view_mode == "diff" then
    lines[#lines+1] = ""
    vim.list_extend(lines, build_diff_lines(details.diff, max_diff, icons, view_mode))
  end
  return lines
end

return M
