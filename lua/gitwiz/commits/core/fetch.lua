
-- commits/core/fetch.lua
local runner = require("gitwiz.core.runner")
local preview_mod = require("gitwiz.commits.core.preview")

local M = {}

-- Fetch commit details (meta, files, diff)
function M.commit_details(hash)
  local show = runner.run({
    "show","-s","--pretty=format:%H%x1f%an%x1f%ae%x1f%ad%x1f%ar%x1f%s","--no-color",hash
  })
  if not show.ok then
    return { ok = false, error = "meta_failed", stderr = show.stderr }
  end
  local parts = {}
  for f in show.stdout:gmatch("([^\31]+)") do parts[#parts+1] = f end
  local meta = {
    hash = parts[1] or hash,
    author = parts[2] or "",
    date = parts[4] or "",
    rel_date = parts[5] or "",
    subject = parts[6] or "",
  }

  local r_files = runner.run({ "diff-tree","--no-commit-id","--name-status","-r", hash })
  local files = {}
  if r_files.ok then
    for _, l in ipairs(r_files.stdout_lines) do
      if l ~= "" then
        local segs = {}
        for s in l:gmatch("[^\t]+") do segs[#segs+1]=s end
        local st = segs[1] or ""
        local path
        if st:match("^R") or st:match("^C") then
          path = segs[3] or segs[2] or ""
        else
          path = segs[2] or ""
        end
        if path and path ~= "" then
          files[#files+1] = { status = st, path = path }
        end
      end
    end
  end

  local r_diff = runner.run({ "show","--pretty=format:","--no-color", hash })
  local diff = {}
  if r_diff.ok then
    local started = false
    for _, l in ipairs(r_diff.stdout_lines) do
      if not started then
        if l ~= "" then started = true; diff[#diff+1] = l end
      else diff[#diff+1] = l end
    end
  end

  return { ok = true, meta = meta, files = files, diff = diff }
end

-- Build lines for preview (wrapper)
function M.build_preview(details, view_mode, cfg, summary)
  return preview_mod.build(details, view_mode, cfg, summary)
end

return M
