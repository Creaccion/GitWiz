-- commits/core/filters.lua (add search hints)
local M = {}

function M.apply(commits, mode)
  if mode == "all" then return commits end
  local out = {}
  for _, c in ipairs(commits) do
    if not c.placeholder and c.category == mode then
      out[#out+1] = c
    end
  end
  if #out == 0 then
    out = {
      {
        placeholder = true,
        reason = "empty_filter",
        mode = mode,
        display = "…No " .. mode .. " commits (g* reset, gs search)",
      },
    }
  end
  return out
end

function M.placeholder_all()
  return {
    {
      placeholder = true,
      reason = "empty_all",
      display = "No commits loaded (g* reset, gs search)",
    },
  }
end

function M.build_placeholder_preview(entry, summary, truncated)
  local lines = {}
  local counts = summary.counts
  local search_part = summary.search and (" | search:'" .. summary.search .. "'") or ""
  lines[#lines+1] = string.format(
    "Summary: primary:%s | ahead:%d behind:%d foreign:%d common:%d total:%d | filter:%s%s",
    summary.primary or "?",
    counts.ahead, counts.behind, counts.foreign, counts.common, counts.total, summary.filter, search_part
  )
  lines[#lines+1] = ""
  if entry.reason == "empty_filter" then
    lines[#lines+1] = "No commits matched filter: " .. entry.mode
  else
    lines[#lines+1] = "No commits available."
  end
  lines[#lines+1] = ""
  lines[#lines+1] = "[Hints]"
  lines[#lines+1] = " Filters: ga(ahead) gb(behind) gf(foreign) gm(common) g*(all)"
  lines[#lines+1] = " Search: gs(new pattern) g/(clear)"
  if truncated and truncated.all then
    lines[#lines+1] = " Increase commits.limit to load deeper history"
  end
  return lines
end

return M
