-- commits/ui/state.lua (add search_query support)
local M = {
  filter_mode = "all",
  counts = nil,
  truncated = nil,
  primary = nil,
  commits_all = {},
  view_modes = {},
  search_query = nil,
}

function M.set_commits(all) M.commits_all = all end
function M.set_counts(c) M.counts = c end
function M.set_truncated(t) M.truncated = t end
function M.set_primary(p) M.primary = p end
function M.set_filter(f) M.filter_mode = f end
function M.set_search(q) M.search_query = q end

function M.summary()
  local s = {
    primary = M.primary and M.primary.name or "?",
    counts = M.counts or { ahead=0, behind=0, foreign=0, common=0, total=0 },
    filter = M.filter_mode,
  }
  if M.search_query and M.search_query ~= "" then
    s.search = M.search_query
  end
  return s
end

return M
