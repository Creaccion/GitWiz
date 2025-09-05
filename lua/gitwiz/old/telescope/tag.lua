local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local tag_actions = require("gitwiz.actions.tag")
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local debug = require("gitwiz.config.debug")

local function format_tag_details(details, entry)
  if not entry then
    return { "No tag selected." }
  end
  local lines = {}
  table.insert(lines, "󰍉  Keymaps: <C-c> Checkout  <C-d> Delete")
  table.insert(lines, "")
  table.insert(lines, " Tag: " .. (entry.value or ""))
  table.insert(lines, "")
  vim.list_extend(lines, vim.split(details, "\n"))
  return lines
end

local M = {}

function M.list_tags()
	local ok, tags = tag_actions.list_tags()
	if not ok then
		print("Failed to get tags: " .. (tags or "unknown error"))
		return
	end
	pickers.new({}, {
		prompt_title = "Git Tags",
		finder = finders.new_table {
			results = tags,
		},
		sorter = conf.generic_sorter({}),
		previewer = previewers.new_buffer_previewer {
			define_preview = function(self, entry)
				local details = tag_actions.get_tag_details(entry.value)
				vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, format_tag_details(details))
			end,
		},
		attach_mappings = function(prompt_bufnr, map)
			-- Checkout tag con <C-c>
			map("i", "<C-c>", function()
				local selection = action_state.get_selected_entry()
				if selection then
					local ok, msg = tag_actions.checkout_tag(selection.value)
					print(ok and msg or ("Error: " .. (msg or "unknown error")))
				end
				actions.close(prompt_bufnr)
			end)
			-- Delete tag con <C-d>
			map("i", "<C-d>", function()
				local selection = action_state.get_selected_entry()
				if selection then
					local ok, msg = tag_actions.delete_tag(selection.value)
					print(ok and msg or ("Error: " .. (msg or "unknown error")))
				end
				actions.close(prompt_bufnr)
			end)
			return true
		end,
	}):find()
end

return M
