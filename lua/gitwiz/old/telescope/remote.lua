local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local remote_actions = require("gitwiz.actions.remote")

local debug = require("gitwiz.config.debug")
local function format_remote_details(details, entry)
	if not entry then
		return { "No remote selected." }
	end
	local lines = {}
	-- Ayuda de keymaps
	table.insert(lines, "󰍉  Keymaps: <C-i> Info  <C-d> Remove")
	table.insert(lines, "")
	-- Resto del formato...
	table.insert(lines, " Remote: " .. (entry.value or ""))
	table.insert(lines, "")
	vim.list_extend(lines, vim.split(details, "\n"))
	return lines
end

local previewer = previewers.new_buffer_previewer {
	define_preview = function(self, entry)
		local details = remote_actions.get_remote_details(entry.value)
		vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, format_remote_details(details))
	end
}

local M = {}

function M.list_remotes()
	local ok, remotes = remote_actions.list_remotes()
	if not ok then
		print("Failed to get remotes: " .. (remotes or "unknown error"))
		return
	end
	-- Extrae solo el nombre del remote para el picker
	local remote_names = {}
	for _, line in ipairs(remotes) do
		local name = line:match("^([%w-_]+)%s")
		if name and not vim.tbl_contains(remote_names, name) then
			table.insert(remote_names, name)
		end
	end
	pickers.new({}, {
		prompt_title = "Git Remotes",
		finder = finders.new_table {
			results = remote_names,
		},
		sorter = conf.generic_sorter({}),
		previewers = previewers
	}):find()
end

return M
