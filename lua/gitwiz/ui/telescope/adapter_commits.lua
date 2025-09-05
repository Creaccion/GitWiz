-- ui/telescope/adapter_commits.lua (modular, colored categories, branch creation on <CR>)
local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local sorters = require("telescope.sorters")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local previewers = require("telescope.previewers")
local telescope_state = require("telescope.state")

local domain_commits = require("gitwiz.domain.commits")
local events = require("gitwiz.core.events")
local config = require("gitwiz.core.config")
local log = require("gitwiz.log")
local runner = require("gitwiz.core.runner")

local cache = require("gitwiz.commits.core.cache")
local filters = require("gitwiz.commits.core.filters")
local highlights = require("gitwiz.commits.core.highlights")
local fetch = require("gitwiz.commits.core.fetch")
local state = require("gitwiz.commits.ui.state")
local act = require("gitwiz.commits.ui.actions")

local entry_display = require("telescope.pickers.entry_display")

local M = {}

local SUBJECT_WIDTH = 60

-- Utils -----------------------------------------------------------------------
local function truncate(subject)
  if #subject <= SUBJECT_WIDTH then return subject end
  return subject:sub(1, SUBJECT_WIDTH - 1) .. "…"
end

local function category_symbol(item, cfg)
  if item.placeholder then return "…" end
  local ci = cfg.commits.preview.category_icons
  return ci[item.category] or "?"
end

local function category_hl(item)
  if item.placeholder then return "GitWizLegend" end
  if item.category == "ahead" then return "GitWizCatAhead"
  elseif item.category == "behind" then return "GitWizCatBehind"
  elseif item.category == "common" then return "GitWizCatCommon"
  elseif item.category == "foreign" then return "GitWizCatForeign"
  end
  return "GitWizLegend"
end

-- Finder ----------------------------------------------------------------------
local function build_finder(commits, cfg)
  local displayer = entry_display.create({
    separator = " ",
    items = {
      { width = 2 },
      { width = 10 },
      { width = 60 },
      { width = 15 },
      { remaining = true },
    },
  })
  return finders.new_table {
    results = commits,
    entry_maker = function(entry)
      local cat_sym = category_symbol(entry, cfg)
      local hl = category_hl(entry)
      local short = entry.placeholder and "" or (entry.short or "")
      local subject = entry.placeholder and entry.display or truncate(entry.subject or "")
      local author = entry.placeholder and "" or (entry.author or "")
      local date = entry.placeholder and "" or (entry.date or "")
      return {
        value = entry,
        display = function()
          return displayer({
            { cat_sym, hl },
            short,
            subject,
            author,
            date,
          })
        end,
        ordinal = entry.placeholder and (entry.display or "placeholder")
          or table.concat({ entry.subject, entry.author, entry.date, entry.hash, entry.category }, " "),
      }
    end,
  }
end

-- Placeholder preview ---------------------------------------------------------
local function build_placeholder(entry, counts, truncated)
  local lines = filters.build_placeholder_preview(entry, {
    primary = state.primary and state.primary.name or "?",
    counts = counts,
    filter = state.filter_mode,
  }, truncated)
  return lines
end

-- Previewer -------------------------------------------------------------------
local function create_previewer(cfg)
  return previewers.new_buffer_previewer({
    title = "Commit Preview",
    define_preview = function(self, entry)
      self.state = self.state or {}
      local vm = self.state.gitwiz_view_mode or "full"
      if not entry or not entry.value then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "No selection" })
        return
      end
      local val = entry.value
      if val.placeholder then
        local cache_key = cache.scoped_key({ "placeholder", state.filter_mode, vm })
        local c = cache.get(cache_key)
        if not c then
          c = build_placeholder(val, state.counts, state.truncated)
          cache.set(cache_key, c)
        end
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, c)
        highlights.apply(self.state.bufnr, c)
        return
      end
      local key = cache.scoped_key({ val.hash, vm, state.filter_mode })
      local cached = cache.get(key)
      if cached then
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, cached)
        highlights.apply(self.state.bufnr, cached)
        return
      end
      local details = fetch.commit_details(val.hash)
      if not details.ok then
        local err = { "Error loading commit:", details.error or "unknown", details.stderr or "" }
        vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, err)
        return
      end
      local lines = fetch.build_preview(details, vm, cfg, state.summary())
      cache.set(key, lines)
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
      highlights.apply(self.state.bufnr, lines)
    end,
  })
end

-- Data refresh ----------------------------------------------------------------
local function refresh_data(limit)
  local res = domain_commits.list({
    limit = limit,
    grep = state.search_query,
  })
  if not res.ok then
    log.error("Failed to list commits: " .. (res.error and res.error.message or ""))
    return false
  end
  state.set_commits(res.data)
  state.set_counts(res.meta.counts)
  state.set_truncated(res.meta.truncated)
  state.set_primary(res.meta.primary_branch)
  return true
end

local function current_view(cfg)
  local all = state.commits_all
  local mode = state.filter_mode
  if #all == 0 then
    return filters.placeholder_all()
  end
  return filters.apply(all, mode)
end

-- Public open -----------------------------------------------------------------
function M.open(opts)
  opts = opts or {}
  local cfg = config.get()
  if not refresh_data(opts.limit) then return end

  local view = current_view(cfg)

  local picker
  picker = pickers.new({}, {
    prompt_title = "GitWiz Commits (modular)",
    finder = build_finder(view, cfg),
    sorter = sorters.get_fzy_sorter(),
    previewer = create_previewer(cfg),
    attach_mappings = function(prompt_bufnr, map)
      local unsubs = {}
      local view_modes = cfg.commits.preview.view_modes
      local vm_index = 1
      picker.previewer.state = picker.previewer.state or {}
      picker.previewer.state.gitwiz_view_mode = view_modes[vm_index]

      local function picker_valid()
        if not vim.api.nvim_buf_is_valid(prompt_bufnr) then return false end
        if picker._completed or picker._closed or picker._disposed then return false end
        local st = telescope_state.get_status(prompt_bufnr)
        if not st then return false end
        if st.prompt_win and not vim.api.nvim_win_is_valid(st.prompt_win) then return false end
        return true
      end

      local function safe_preview(entry)
        if not picker_valid() then return end
        pcall(function()
          local status = telescope_state.get_status(prompt_bufnr)
          if status then picker.previewer:preview(entry, status) end
        end)
      end

      local function register_event(name, cb)
        local _, off = events.on(name, cb)
        unsubs[#unsubs+1] = off
      end

      local function cleanup()
        for _, off in ipairs(unsubs) do pcall(off) end
        unsubs = {}
      end

      local function rebuild()
        local v = current_view(cfg)
        picker:refresh(build_finder(v, cfg), { reset_prompt = false })
      end

      local function repreview()
        if not picker_valid() then return end
        local entry = action_state.get_selected_entry()
        if not entry then return end
        safe_preview(entry)
      end

      local function refresh_all()
        if not picker_valid() then return end
        if refresh_data(opts.limit) then
          rebuild()
          repreview()
        end
      end

      local function set_filter(mode)
        state.set_filter(mode)
        rebuild()
        repreview()
        log.info("[GitWiz] Filter: " .. mode)
      end

      local function toggle_view_mode()
        vm_index = (vm_index % #view_modes) + 1
        picker.previewer.state.gitwiz_view_mode = view_modes[vm_index]
        repreview()
        log.info("[GitWiz] View mode: " .. view_modes[vm_index])
      end

      local function copy_preview()
        if not picker_valid() then return end
        local pbuf = picker.previewer.state.bufnr
        if not pbuf or not vim.api.nvim_buf_is_valid(pbuf) then return end
        local lines = vim.api.nvim_buf_get_lines(pbuf, 0, -1, false)
        local txt = table.concat(lines, "\n")
        vim.fn.setreg('"', txt)
        pcall(vim.fn.setreg, '+', txt)
        log.info("[GitWiz] Preview copied (" .. #lines .. " lines)")
      end

      local function gather_selected()
        local pk = action_state.get_current_picker(prompt_bufnr)
        local sels = pk:get_multi_selection()
        if #sels == 0 then
          local sel = action_state.get_selected_entry()
          if sel then sels = { sel } end
        end
        local entries = {}
        for _, e in ipairs(sels) do
          entries[#entries+1] = e.value
        end
        return entries
      end

      local function do_toggle()
        local entries = gather_selected()
        if #entries == 0 then
          log.warn("No commit selected")
          return
        end
        act.toggle(entries, refresh_all)
      end

      local function do_cherry_pick()
        local entries = gather_selected()
        if #entries == 0 then
          log.warn("No commit selected")
          return
        end
        act.cherry_pick(entries, refresh_all)
      end

      -- Branch creation from selected commit (Enter)
      local function create_branch_from_commit()
        if not picker_valid() then return end
        local entry = action_state.get_selected_entry()
        if not entry or not entry.value or entry.value.placeholder then
          log.warn("No commit selected")
          return
        end
        local hash = entry.value.hash
        local short = entry.value.short or hash:sub(1, 7)
        local default_name = "commit/" .. short
        local input = vim.fn.input("New branch name (default " .. default_name .. "): ")
        if input == nil then return end
        local branch = vim.trim(input)
        if branch == "" then branch = default_name end
        if vim.fn.confirm("Create & switch to branch '" .. branch .. "' at " .. short .. "?", "&Yes\n&No", 2) ~= 1 then
          return
        end
        -- Check existence
        local exist = runner.run({ "show-ref", "--verify", "--quiet", "refs/heads/" .. branch })
        if exist.ok then
          log.warn("Branch already exists: " .. branch)
          return
        end
        local r = runner.run({ "switch", "-c", branch, hash })
        if not r.ok then
          log.error("Branch creation failed: " .. (r.stderr or ""))
          return
        end
        log.info("Switched to new branch: " .. branch)
        cleanup()
        actions.close(prompt_bufnr)
      end

      -- Keymaps
      map("i", "<C-p>", do_cherry_pick)
      map("n", "<C-p>", do_cherry_pick)
      map("i", "<C-t>", do_toggle)
      map("n", "<C-t>", do_toggle)
      map("i", cfg.commits.preview.key_toggle_view, toggle_view_mode)
      map("n", cfg.commits.preview.key_toggle_view, toggle_view_mode)
      map("i", "<C-y>", copy_preview)
      map("n", "<C-y>", copy_preview)
      -- Disable default Telescope shift-tab multi select
      map("i", "<S-Tab>", function() end)
      map("n", "<S-Tab>", function() end)
      -- Enter -> create/switch branch
      map("i", "<CR>", create_branch_from_commit)
      map("n", "<CR>", create_branch_from_commit)

      -- Filters
      local filter_keys = {
        ahead = "ga",
        behind = "gb",
        foreign = "gf",
        common = "gm",
        all = "g*",
      }
      for mode, lhs in pairs(filter_keys) do
        map("n", lhs, function() set_filter(mode) end)
        map("i", lhs, function() set_filter(mode) end)
      end

      -- Content search (diff)
      local function run_search()
        local pattern = vim.fn.input("Diff search (regex -G): ")
        if pattern == nil then return end
        pattern = vim.trim(pattern)
        if pattern == "" then
          state.set_search(nil)
        else
          state.set_search(pattern)
        end
        cache.clear()
        refresh_all()
      end

      local function clear_search()
        if not state.search_query then
          log.info("[GitWiz] No active search")
          return
        end
        state.set_search(nil)
        cache.clear()
        refresh_all()
        log.info("[GitWiz] Search cleared")
      end

      map("n", "gs", run_search)
      map("i", "gs", run_search)
      map("n", "g/", clear_search)
      map("i", "g/", clear_search)

      -- Events (sin refresh en conflicto)
      local function safe_refresh_on_event()
        if not picker_valid() then return end
        refresh_all()
      end
      register_event("cherry_pick:success", safe_refresh_on_event)
      register_event("cherry_pick:done", safe_refresh_on_event)
      register_event("cherry_pick:applied", safe_refresh_on_event)
      register_event("revert:success", safe_refresh_on_event)
      register_event("revert:done", safe_refresh_on_event)
      register_event("revert:applied", safe_refresh_on_event)
      register_event("cherry_pick:conflict", function() end)
      register_event("revert:conflict", function() end)

      local orig_close = picker._on_close
      picker._on_close = function(...)
        cleanup()
        if orig_close then pcall(orig_close, ...) end
      end

      return true
    end,
  })

  picker:find()
end

return M
