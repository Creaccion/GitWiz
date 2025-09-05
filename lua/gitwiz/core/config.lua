-- core/config.lua (add primary_branch_override + candidate list)
local M = {}

local defaults = {
  commits = {
    limit = 3000,
    key_toggle_commit = "<C-t>",
    preview = {
      max_diff_lines = 400,
      view_modes = { "full", "files", "diff", "meta" },
      key_toggle_view = "<Tab>",
      icons = {
        commit = "",
        file = "󰈙",
        diff = "󰡙",
        added = "",
        modified = "",
        removed = "",
        renamed = "",
        current = "✔",
        not_current = "✘",
      },
      category_icons = {
        ahead = "⇡",
        behind = "⇣",
        common = "✔",
        foreign = "⋄",
      },
    },
  },
  conflicts = {
    auto_open = true,
    auto_close = true,
    layout = "tab",
    show_base = false,
    show_keymaps = true,
    show_meta = true,
    keep_both_separator = "====== OURS / THEIRS ======",
    keymaps = {
      tree = { open = { "<CR>", "o" }, refresh = "r", close = "q", next = "]c", prev = "[c", mark_resolved = "R" },
      working = {
        pick_ours = "<leader>co",
        pick_theirs = "<leader>ct",
        pick_base = "<leader>cb",
        mark_resolved = "<leader>cr",
        continue_pick = "<leader>cc",
        abort_pick = "<leader>ca",
        skip_pick = "<leader>cs",
        next_file = "<leader>cn",
        prev_file = "<leader>cp",
        keep_both = "<leader>ck",
        clean_markers = "<leader>cm",
        quit_to_tree = "q",
        close_all = "<leader>cQ",
      },
    },
  },
  graph = {
    stale_days = 14,
    log_lines = 40,
    include_remotes = false,
    show_legend = true,
    max_commits_global = 400,
    lanes_mode_default = "compact",
    colorize = true,
    show_refs_inline = true,
    subject_truncate = 48,
    lanes_colors_max = 12,
    labels_mode = "birth",
    birth_symbol = "◜",
    focus_key = "gF",
    refs_parenthesis = true,
    repeat_every = 12,
  },
  -- NEW: primary branch detection overrides
  primary_branch_override = nil,           -- e.g. "develop"
  primary_branch_candidates = { "main", "master", "develop", "trunk" },
  runner = { timeout = 10000 },
}

local state = vim.deepcopy(defaults)

function M.setup(opts)
  if opts then
    state = vim.tbl_deep_extend("force", state, opts)
  end
end

function M.get() return state end
function M.get_defaults() return vim.deepcopy(defaults) end

return M
