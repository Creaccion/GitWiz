local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local stash_actions = require("gitwiz.actions.stash")
local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')
local debug = require("gitwiz.config.debug")

local function format_stash_details(details, entry)
  if not entry then
    return { "No stash selected." }
  end
  local lines = {}
  -- Ayuda de keymaps
  table.insert(lines, "󰍉  Keymaps: <C-a> Apply  <C-d> Drop")
  table.insert(lines, "")
  -- Resto del formato...
  local ref, msg = entry.value:match("^(stash@{%d+}):%s*(.+)$")
  table.insert(lines, " Stash: " .. (ref or details.ref or ""))
  if msg then
    table.insert(lines, " Message: " .. msg)
  end
  table.insert(lines, "")
  if #details.files > 0 then
    table.insert(lines, " Files changed:")
    for _, file in ipairs(details.files) do
      table.insert(lines, "  " .. file)
    end
    table.insert(lines, "")
  end
  if #details.diff > 0 then
    table.insert(lines, " Diff:")
    for _, line in ipairs(details.diff) do
      table.insert(lines, line)
    end
  end
  return lines
end

local M = {}

function M.list_stashes()
	local ok, stashes = stash_actions.list_stashes()
	if not ok then
		print("Failed to get stashes: " .. (stashes or "unknown error"))
		return
	end
	pickers.new({}, {
		prompt_title = "Git Stashes",
		finder = finders.new_table {
			results = stashes,
		},
		sorter = conf.generic_sorter({}),
		previewer = previewers.new_buffer_previewer {
			define_preview = function(self, entry)
				local ref = entry.value:match("stash@{%d+}")
				local ok, details = stash_actions.get_stash_details(ref)
				local lines
				if not ok then
					lines = { details.error or "Unknown error" }
				else
					lines = format_stash_details(details, entry)
				end
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			end,
		},
  attach_mappings = function(prompt_bufnr, map)
    -- Aplicar stash con <C-a>
    map("i", "<C-a>", function()
      local selection = action_state.get_selected_entry()
      if selection then
        local ref = selection.value:match("stash@{%d+}")
        local ok, msg = stash_actions.apply_stash(ref)
        print(ok and msg or ("Error: " .. (msg or "unknown error")))
      end
      actions.close(prompt_bufnr)
    end)
    -- Eliminar stash con <C-d>
    map("i", "<C-d>", function()
      local selection = action_state.get_selected_entry()
      if selection then
        local ref = selection.value:match("stash@{%d+}")
        local ok, msg = stash_actions.drop_stash(ref)
        print(ok and msg or ("Error: " .. (msg or "unknown error")))
      end
      actions.close(prompt_bufnr)
    end)
    return true
  end,
	}):find()
end

return M
