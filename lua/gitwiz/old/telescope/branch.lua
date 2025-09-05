-- Telescope sources and pickers for GitWiz
local M = {}

local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local branch_actions = require("gitwiz.actions.branch")
local telescope_actions = require("telescope.actions")
local actions = require("gitwiz.actions")
local previewer_utils = require("gitwiz.telescope.previewer")
local branch_ui = require("gitwiz.ui.branch")
local rebase_buffer = require("gitwiz.buffer.rebase")
local commit_actions = require("gitwiz.actions.commit")
local debug = require("gitwiz.config.debug")

local function has_commits_to_rebase(base_branch)
	base_branch = base_branch:gsub("\n", "")
	print("Checking: git log " .. base_branch .. "..HEAD")
	local log = vim.fn.systemlist("git log " .. base_branch .. "..HEAD")
	print("Found commits: ", #log)
	return #log > 0
end

local function format_branch_details(details)
	local lines = {}
	table.insert(lines, " Branch: " .. (details.branch or ""))
	table.insert(lines, " Last Commit: " .. (details.hash or ""))
	table.insert(lines, " Author: " .. (details.author or ""))
	table.insert(lines, " Date:   " .. (details.date or ""))
	table.insert(lines, "")
	table.insert(lines, " Message:")
	table.insert(lines, "  " .. (details.message or ""))
	table.insert(lines, "")
	if #details.files > 0 then
		table.insert(lines, " Files changed in last commit:")
		for _, file in ipairs(details.files) do
			table.insert(lines, "  " .. file)
		end
		table.insert(lines, "")
	end
	if #details.unique_commits > 0 then
		table.insert(lines, " Unique commits (not in main):")
		for _, uc in ipairs(details.unique_commits) do
			if uc ~= "" then
				table.insert(lines, "  " .. uc)
			end
		end
	end
	return lines
end

-- Helper to reload branches in the picker
local function reload_branches(prompt_bufnr)
	local handle = io.popen("git branch --all --color=never")
	local result = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	local picker = action_state.get_current_picker(prompt_bufnr)
	picker:refresh(finders.new_table({ results = branches }), { reset_prompt = true })
end
-- List Git branches using Telescope
function M.list_branches()
	local ok, branches = branch_actions.list_branches({ all = true })
	if not ok then
		print("Failed to get branches: " .. (branches or "unknown error"))
		return
	end

	if #branches == 0 then
		print("No branches found in this repository.")
		return
	end

	pickers
	    .new({}, {
		    prompt_title = "Git Branches",
		    finder = finders.new_table({
			    results = branches,
		    }),
		    sorter = conf.generic_sorter({}),
                     previewer = previewer_utils.branch_previewer,
		    attach_mappings = function(_, map)
			    map("i", "<CR>", function(prompt_bufnr)
				    local selection = action_state.get_selected_entry()
				    if selection then
					    local ok, msg = branch_actions.checkout_branch(selection[1])
					    if ok then
						    print("Switched to branch: " .. selection[1])
					    else
						    print("Error: " .. (msg or "unknown error"))
					    end
				    end
				    telescope_actions.close(prompt_bufnr)
			    end)
			    map("i", "<C-r>", function(prompt_bufnr)
				    local selection = action_state.get_selected_entry()
				    if selection then
					    local new_name = vim.fn.input("New branch name: ")
					    if new_name ~= "" then
						    branch_actions.rename_branch(selection[1], new_name)
					    end
				    end
				    reload_branches(prompt_bufnr)
			    end)
			    map("i", "<C-d>", function(prompt_bufnr)
				    local selection = action_state.get_selected_entry()
				    if selection then
					    local confirm = vim.fn.input("Delete branch '" ..
						    selection[1] .. "'? (y/n): ")
					    if confirm:lower() == "y" then
						    local ok, msg = branch_actions.delete_branch(selection[1])
						    if ok then
							    print("Branch deleted: " .. selection[1])
						    else
							    print("Error: " .. (msg or "unknown error"))
						    end
					    end
				    end
				    reload_branches(prompt_bufnr)
			    end)
			    return true
		    end,
	    })
	    :find()
end

function M.create_branch_picker()
	vim.ui.input({ prompt = "New branch name: " }, function(input)
		if not input or input == "" then
			print("Branch name cannot be empty.")
			return
		end
		vim.ui.input({ prompt = "Base branch (leave empty for HEAD): " }, function(base)
			if base == "" then base = nil end
			local ok, msg = branch_actions.create_branch(input, base)
			if ok then
				vim.ui.select({ "Yes", "No" }, { prompt = "Switch to new branch?" }, function(choice)
					if choice == "Yes" then
						branch_actions.checkout_branch(input)
					else
						print("Staying on current branch.")
					end
				end)
			else
				print("Error creating branch: " .. msg)
			end
		end)
	end)
end

--
-- Picker to rename a branch
function M.rename_branch_picker()
	local handle = io.popen("git branch --color=never")
	local result = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	local old_name = vim.fn.input("Branch to rename: ", branches[1] or "")
	if old_name == "" then
		print("Branch name required.")
		return
	end
	local new_name = vim.fn.input("New branch name: ")
	if new_name == "" then
		print("New branch name required.")
		return
	end

	local ok, msg = require("gitwiz.actions.branch").rename_branch(old_name, new_name)
	if not ok then
		print("Error: " .. msg)
	end
end

-- Picker to delete a branch
function M.delete_branch_picker()
	local handle = io.popen("git branch --color=never")
	local result = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	local branch_name = vim.fn.input("Branch to delete: ", branches[1] or "")
	if branch_name == "" then
		print("Branch name required.")
		return
	end

	local ok, msg = require("gitwiz.actions.branch").delete_branch(branch_name)
	if not ok then
		print("Error: " .. msg)
	end
end

function M.merge_branch_picker()
	local handle = io.popen("git branch --color=never")
	local result = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	pickers
	    .new({}, {
		    prompt_title = "Merge Branch Into Current",
		    finder = finders.new_table({ results = branches }),
		    sorter = conf.generic_sorter({}),
		    attach_mappings = function(_, map)
			    map("i", "<CR>", function(prompt_bufnr)
				    local selection = action_state.get_selected_entry()
				    if selection then
					    local ok, msg = require("gitwiz.actions.branch").merge_branch(selection[1])
					    if ok then
						    print("Merge successful!")
					    else
						    print("Merge failed: " .. msg)
					    end
				    end
				    telescope_actions.close(prompt_bufnr)
			    end)
			    return true
		    end,
	    })
	    :find()
end

-- Picker to start interactive rebase onto a selected branch, with detailed preview and buffer integration
function M.interactive_rebase_picker()
	local handle = io.popen("git branch --color=never")
	local result = handle and handle:read("*a") or ""
	if handle then
		handle:close()
	end

	local branches = {}
	for line in result:gmatch("[^\r\n]+") do
		local branch = line:gsub("^%* ", ""):gsub("^%s+", "")
		table.insert(branches, branch)
	end

	pickers
	    .new({}, {
		    prompt_title = "Interactive Rebase Onto Branch",
		    finder = finders.new_table({ results = branches }),
		    sorter = conf.generic_sorter({}),
		    previewer = previewer_utils.new_buffer_previewer({
			    define_preview = function(self, entry)
				    local current_branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")
				    local target_branch = entry.value:gsub("\n", "")
				    local log_cmd = string.format(
					    "git log --pretty=format:'%%h | %%an | %%ar | %%s' %s..%s",
					    target_branch,
					    current_branch
				    )
				    local log_output = vim.fn.system(log_cmd)
				    local lines = {}
				    table.insert(lines,
					    "Commits in " .. current_branch .. " not in " .. target_branch .. ":")
				    table.insert(
					    lines,
					    "────────────────────────────"
				    )
				    if log_output == "" then
					    table.insert(lines,
						    "✅ No commits to rebase. The branch is up to date or already rebased.")
				    else
					    table.insert(lines, "Hash      | Author        | Date         | Message")
					    table.insert(lines, "--------------------------------------------------")
					    for line in log_output:gmatch("[^\r\n]+") do
						    table.insert(lines, line)
					    end
					    table.insert(
						    lines,
						    "────────────────────────────"
					    )
					    table.insert(
						    lines,
						    "⚠️  Git will rebase automatically if no conflicts or edits are needed."
					    )
					    table.insert(lines,
						    "No interactive editing will be possible unless intervention is required.")
				    end
				    table.insert(
					    lines,
					    "────────────────────────────"
				    )
				    -- Relación ahead/behind
				    for _, l in ipairs(branch_ui.branch_relationship(current_branch, target_branch)) do
					    table.insert(lines, l)
				    end
				    -- Opcional: resumen de archivos cambiados entre ramas
				    local diff_cmd = string.format("git diff --name-status %s..%s", target_branch,
					    current_branch)
				    local diff_output = vim.fn.system(diff_cmd)
				    if diff_output ~= "" then
					    table.insert(lines, "Files changed between branches:")
					    for diff_line in diff_output:gmatch("[^\r\n]+") do
						    table.insert(lines, "  " .. diff_line)
					    end
					    table.insert(
						    lines,
						    "────────────────────────────"
					    )
				    end
				    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, lines)
			    end,
		    }),
		    attach_mappings = function(_, map)
			    map("i", "<CR>", function(prompt_bufnr)
				    local selection = action_state.get_selected_entry()
				    if selection then
					    local base_branch = selection[1]:gsub("\n", "")
					    local log = vim.fn.systemlist("git log " .. base_branch .. "..HEAD")
					    if #log == 0 then
						    print("No commits to rebase onto " .. base_branch)
						    return
					    end
					    telescope_actions.close(prompt_bufnr)
					    -- Lanza el rebase interactivo estándar en una terminal integrada
					    vim.cmd(string.format("tabnew | terminal git rebase -i %s", base_branch))
					    vim.defer_fn(function()
						    local git_dir = vim.fn.system("git rev-parse --git-dir"):gsub("\n",
							    "")
						    local rebase_todo = git_dir .. "/rebase-merge/git-rebase-todo"
						    if vim.fn.filereadable(rebase_todo) == 1 then
							    vim.cmd("edit " .. rebase_todo)
						    end
					    end, 1000)
					    print("Interactive rebase started in terminal. Edit the sequence as needed.")
					    print("GitWiz UI will enrich the rebase buffer automatically.")
				    end
			    end)
			    return true
		    end,
	    })
	    :find()
end

return M
