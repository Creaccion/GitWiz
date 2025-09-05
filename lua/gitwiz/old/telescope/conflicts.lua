local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local commit_actions = require("gitwiz.actions.commit_actions")
local log = require("gitwiz.log")

local M = {}

local function get_conflicts()
  return commit_actions.get_conflicts()
end

local function open_file_at_conflict(filepath)
  if not filepath or filepath == "" then
    return
  end
  vim.cmd("edit " .. filepath)
  -- Jump to first conflict marker
  local line_count = vim.api.nvim_buf_line_count(0)
  for i = 1, math.min(line_count, 8000) do
    local line = vim.api.nvim_buf_get_lines(0, i - 1, i, false)[1]
    if line and line:match("^<<<<<<<") then
      vim.api.nvim_win_set_cursor(0, { i, 0 })
      break
    end
  end
end

local function apply_side(filepath, side)
  if not filepath then return end
  local cmd
  if side == "ours" then
    cmd = "git checkout --ours -- " .. filepath
  else
    cmd = "git checkout --theirs -- " .. filepath
  end
  local out = vim.fn.system(cmd)
  if vim.v.shell_error ~= 0 then
    log.error("Failed applying side " .. side .. " for " .. filepath .. " out: " .. out)
  else
    log.info("Applied " .. side .. " for " .. filepath)
  end
end

local function mark_resolved(filepath)
  if not filepath then return end
  local out = vim.fn.system({ "git", "add", "--", filepath })
  if vim.v.shell_error ~= 0 then
    log.error("git add failed for " .. filepath .. " out: " .. (out or ""))
  else
    log.info("Marked resolved: " .. filepath)
  end
end

local function refresh_picker(picker)
  local files = get_conflicts()
  picker:refresh(finders.new_table {
    results = files,
    entry_maker = function(item)
      return {
        value = item,
        display = item,
        ordinal = item,
      }
    end,
  }, { reset_prompt = false })
end

function M.open()
  local files = get_conflicts()
  if #files == 0 then
    log.info("No conflicts to show")
    return
  end

  pickers.new({}, {
    prompt_title = "Git Conflicts",
    finder = finders.new_table {
      results = files,
      entry_maker = function(item)
        return {
          value = item,
          display = item,
          ordinal = item,
        }
      end,
    },
    sorter = conf.generic_sorter({}),
    attach_mappings = function(prompt_bufnr, map)
      local picker = action_state.get_current_picker(prompt_bufnr)

      local function current_file()
        local entry = action_state.get_selected_entry()
        return entry and entry.value
      end

      local function do_open()
        local f = current_file()
        actions.close(prompt_bufnr)
        open_file_at_conflict(f)
      end

      local function use_ours()
        local f = current_file()
        apply_side(f, "ours")
        refresh_picker(picker)
      end

      local function use_theirs()
        local f = current_file()
        apply_side(f, "theirs")
        refresh_picker(picker)
      end

      local function resolve()
        local f = current_file()
        mark_resolved(f)
        refresh_picker(picker)
      end

      local function do_refresh()
        refresh_picker(picker)
      end

      map("i", "<CR>", do_open)
      map("n", "<CR>", do_open)
      map("i", "<C-o>", use_ours)
      map("n", "<C-o>", use_ours)
      map("i", "<C-t>", use_theirs)
      map("n", "<C-t>", use_theirs)
      map("i", "<C-a>", resolve)
      map("n", "<C-a>", resolve)
      map("i", "<C-r>", do_refresh)
      map("n", "<C-r>", do_refresh)

      return true
    end,
  }):find()
end

return M
