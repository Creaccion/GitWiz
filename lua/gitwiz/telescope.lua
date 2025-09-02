-- Telescope sources and pickers for GitWiz
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local previewers = require("telescope.previewers")
local action_state = require("telescope.actions.state")
local telescope_actions = require("telescope.actions")
local actions = require("gitwiz.actions")
local ui = require("gitwiz.ui")

-- List Git branches using Telescope
function M.list_branches()
	local handle = io.popen("git branch --all --color=never")
	if not handle then
		print("Failed to run git branch")
		return
	end
	local result = handle:read("*a")
	handle:close()

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	pickers
		.new({}, {
			prompt_title = "Git Branches",
			finder = finders.new_table({
				results = branches,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_buffer_previewer({
				define_preview = function(self, entry)
					local lines = ui.get_branch_info(entry.value)
					local clean_lines = {}
					for _, line in ipairs(lines) do
						for subline in tostring(line):gmatch("[^\r\n]+") do
							table.insert(clean_lines, subline)
						end
					end
					vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, clean_lines)
				end,
			}),
			attach_mappings = function(_, map)
				map("i", "<CR>", function(prompt_bufnr)
					local selection = action_state.get_selected_entry()
					if selection then
						actions.checkout_branch(selection[1])
					end
					telescope_actions.close(prompt_bufnr)
				end)
				return true
			end,
		})
		:find()
end

return M
