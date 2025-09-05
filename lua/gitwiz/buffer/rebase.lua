-- Buffer dedicated for interactive rebase editing in GitWiz
local M = {}
local debug = require("gitwiz.config.debug")

function M.generate_rebase_todo(base_branch)
	local hashes = vim.fn.systemlist("git rev-list --reverse " .. base_branch .. "..HEAD")
	if #hashes == 0 then
		print("No commits to rebase.")
		return false
	end
	local lines = {}
	for _, hash in ipairs(hashes) do
		local msg = vim.fn.system("git log -1 --pretty=%s " .. hash):gsub("\n", "")
		table.insert(lines, string.format("pick %s %s", hash, msg))
	end
	-- Escribe el archivo en .git/rebase-merge/git-rebase-todo
	local git_dir = vim.fn.system("git rev-parse --git-dir"):gsub("\n", "")
	local rebase_dir = git_dir .. "/rebase-merge"
	if vim.fn.isdirectory(rebase_dir) == 0 then
		vim.fn.mkdir(rebase_dir, "p")
	end
	vim.fn.writefile(lines, rebase_dir .. "/git-rebase-todo")
	-- Marca el inicio del rebase (puedes crear archivos adicionales si Git los requiere)
	print("Rebase todo generated. Ready for interactive UI.")
	return true
end
-- Helper to get the rebase todo file path
local function get_rebase_todo_file()
	local git_dir = vim.fn.system("git rev-parse --git-dir"):gsub("\n", "")
	local rebase_file = git_dir .. "/rebase-merge/git-rebase-todo"
	if vim.fn.filereadable(rebase_file) == 0 then
		rebase_file = git_dir .. "/rebase-apply/git-rebase-todo"
		if vim.fn.filereadable(rebase_file) == 0 then
			return nil
		end
	end
	return rebase_file
end

-- Parse rebase_todo into a table
local function parse_rebase_todo()
	local rebase_file = get_rebase_todo_file()
	if not rebase_file then
		return {}
	end
	local lines = vim.fn.readfile(rebase_file)
	local commits = {}
	for _, line in ipairs(lines) do
		local cmd, hash, msg = line:match("^(%w+)%s+(%w+)%s*(.*)")
		if cmd and hash then
			table.insert(commits, { cmd = cmd, hash = hash, msg = msg })
		end
	end
	return commits
end

-- Detect rebase state and current commit
local function detect_rebase_state(commits)
	local git_dir = vim.fn.system("git rev-parse --git-dir"):gsub("\n", "")
	local head_file = git_dir .. "/rebase-merge/current"
	if vim.fn.filereadable(head_file) == 1 then
		local current_hash = vim.fn.readfile(head_file)[1]
		for i, commit in ipairs(commits) do
			if commit.hash == current_hash then
				return i
			end
		end
	end
	return 1
end

-- Render custom float for rebase UI with command editing and confirmation
function M.open_rebase_ui(selected_idx, base_branch)
	-- Cierra buffers del archivo estándar si están abiertos
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(buf)
		if name:match("git%-rebase%-todo$") then
			vim.api.nvim_buf_delete(buf, { force = true })
		end
	end

	local commits = parse_rebase_todo()
	if #commits == 0 then
		print("No interactive rebase in progress.")
		return
	end

	selected_idx = selected_idx or detect_rebase_state(commits)
	base_branch = base_branch or ""

	-- Prepare left column: commit list
	local left_lines = {}
	for i, commit in ipairs(commits) do
		local mark = (i == selected_idx) and "➤" or "  "
		local reviewed = (i < selected_idx) and "✔️" or " "
		table.insert(left_lines, string.format("%s %s [%s] %s %s", mark, reviewed, commit.cmd, commit.hash, commit.msg))
	end

	-- Prepare right column: commit details
	local selected_commit = commits[selected_idx]
	local info = vim.fn.system(
		string.format(
			"git show --stat --pretty=format:'Hash: %%h\nAuthor: %%an\nDate: %%ad\nMessage: %%s\n' %s",
			selected_commit.hash
		)
	)
	local info_lines = {}
	for l in info:gmatch("[^\r\n]+") do
		table.insert(info_lines, l)
	end

	-- Build two columns
	local max_left = 0
	for _, l in ipairs(left_lines) do
		if #l > max_left then
			max_left = #l
		end
	end
	local float_lines = {}
	local max_rows = math.max(#left_lines, #info_lines)
	for i = 1, max_rows do
		local left = left_lines[i] or ""
		local right = info_lines[i] or ""
		local pad = string.rep(" ", max_left - #left + 4)
		table.insert(float_lines, left .. pad .. right)
	end

	table.insert(float_lines, string.rep("-", max_left + 40))

	-- Ayuda de keymaps y fast-forward
	local branch_ui = require("gitwiz.ui.branch")
	local current_branch = vim.fn.system("git rev-parse --abbrev-ref HEAD"):gsub("\n", "")
	local help =
		"Keymaps: <Up>/<Down> navigate  <C-p> pick  <C-s> squash  <C-e> edit  <C-r> reword  <C-d> drop  <leader>w: continue  <leader>q: abort  <Esc>: close"
	if branch_ui.can_fast_forward(current_branch, base_branch) then
		help = help .. "  <leader>f: fast-forward base branch to current"
	end
	table.insert(float_lines, help)
	table.insert(float_lines, "Press a command key to change the action for the selected commit.")

	-- Crear ventana flotante
	local buf = vim.api.nvim_create_buf(false, true)
	local width = math.min(100, math.floor(vim.o.columns * 0.8))
	local height = math.min(20, math.floor(vim.o.lines * 0.4))
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		row = 2,
		col = math.floor((vim.o.columns - width) / 2),
		style = "minimal",
		border = "rounded",
	}
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, float_lines)
	local win = vim.api.nvim_open_win(buf, true, opts)

	-- Helper to update command and redraw with confirmation
	local function update_command(new_cmd)
		local confirm = vim.fn.input(string.format("Change to '%s'? (y/n): ", new_cmd))
		if confirm:lower() ~= "y" then
			print("Command change cancelled.")
			return
		end
		commits[selected_idx].cmd = new_cmd
		local rebase_file = get_rebase_todo_file()
		local out_lines = {}
		for _, c in ipairs(commits) do
			table.insert(out_lines, string.format("%s %s %s", c.cmd, c.hash, c.msg))
		end
		vim.fn.writefile(out_lines, rebase_file)
		vim.api.nvim_win_close(win, true)
		M.open_rebase_ui(selected_idx, base_branch)
	end

	-- Confirm before continue/abort
	local function confirm_and_run(cmd, msg)
		local confirm = vim.fn.input(msg .. " (y/n): ")
		if confirm:lower() == "y" then
			vim.cmd(cmd)
		else
			print("Action cancelled.")
		end
	end

	-- Mapeos para navegación y acciones
	vim.keymap.set("n", "<Esc>", function()
		vim.api.nvim_win_close(win, true)
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<Up>", function()
		if selected_idx > 1 then
			selected_idx = selected_idx - 1
		end
		vim.api.nvim_win_close(win, true)
		M.open_rebase_ui(selected_idx, base_branch)
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<Down>", function()
		if selected_idx < #commits then
			selected_idx = selected_idx + 1
		end
		vim.api.nvim_win_close(win, true)
		M.open_rebase_ui(selected_idx, base_branch)
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<C-p>", function()
		update_command("pick")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<C-s>", function()
		update_command("squash")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<C-e>", function()
		update_command("edit")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<C-r>", function()
		update_command("reword")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<C-d>", function()
		update_command("drop")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<leader>w", function()
		confirm_and_run("!git rebase --continue", "Continue rebase?")
	end, { buffer = buf, nowait = true })
	vim.keymap.set("n", "<leader>q", function()
		confirm_and_run("!git rebase --abort", "Abort rebase?")
	end, { buffer = buf, nowait = true })

	-- Fast-forward base branch if possible
	if branch_ui.can_fast_forward(current_branch, base_branch) then
		vim.keymap.set("n", "<leader>f", function()
			local confirm = vim.fn.input(string.format("Fast-forward %s to %s? (y/n): ", base_branch, current_branch))
			if confirm:lower() == "y" then
				vim.cmd(string.format("!git checkout %s && git merge --ff-only %s", base_branch, current_branch))
				print(string.format("%s fast-forwarded to %s.", base_branch, current_branch))
			else
				print("Fast-forward cancelled.")
			end
		end, { buffer = buf, nowait = true })
	end
end

function M.enrich_rebase_buffer()
	local function change_action(action)
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local line = vim.api.nvim_get_current_line()
		local rest = line:match("^%w+%s+(.*)")
		if rest then
			vim.api.nvim_set_current_line(action .. " " .. rest)
		end
	end

	-- Mueve la línea actual arriba/abajo
	local function move_line(delta)
		local row = vim.api.nvim_win_get_cursor(0)[1]
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		if row + delta < 1 or row + delta > #lines then
			return
		end
		local tmp = lines[row]
		lines[row] = lines[row + delta]
		lines[row + delta] = tmp
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
		vim.api.nvim_win_set_cursor(0, { row + delta, 0 })
	end
	local filename = vim.fn.expand("%:t")
	if not filename:match("git%-rebase%-todo") then
		return
	end

	-- Helper: highlight groups
	vim.api.nvim_set_hl(0, "GitWizCmd", { fg = "#FFD700", bold = true })
	vim.api.nvim_set_hl(0, "GitWizHash", { fg = "#87d7ff", bold = true })
	vim.api.nvim_set_hl(0, "GitWizCurrent", { bg = "#444444" })

	-- Insert keymap help at the top
  local help = "# <C-p>:pick <C-s>:squash <C-e>:edit <C-r>:reword <C-d>:drop <C-k>/<C-j>:move <leader>w:continue <leader>q:abort <leader>s:skip <leader>p:preview"
	local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	if lines[1] ~= help then
		table.insert(lines, 1, help)
		vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
	end

	-- Highlight commands, hashes, and current line
	local function apply_highlights()
		local buf = vim.api.nvim_get_current_buf()
		vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
		local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		for i, line in ipairs(lines) do
			if i == 1 then
				vim.api.nvim_buf_add_highlight(buf, -1, "Comment", i - 1, 0, -1)
			else
				local cmd, hash = line:match("^(%w+)%s+(%w+)")
				if cmd then
					vim.api.nvim_buf_add_highlight(buf, -1, "GitWizCmd", i - 1, 0, #cmd)
				end
				if hash then
					local s, e = line:find("%w+%s+(%w+)")
					if s and e then
						vim.api.nvim_buf_add_highlight(buf, -1, "GitWizHash", i - 1, s - 1, e)
					end
				end
			end
		end
		-- Highlight current line
		local row = vim.api.nvim_win_get_cursor(0)[1]
		vim.api.nvim_buf_add_highlight(buf, -1, "GitWizCurrent", row - 1, 0, -1)
	end

	-- Preview float management
	local float_win = nil
	local function close_float()
		if float_win and vim.api.nvim_win_is_valid(float_win) then
			vim.api.nvim_win_close(float_win, true)
			float_win = nil
		end
	end

	local function show_commit_floating()
		close_float()
		local line = vim.api.nvim_get_current_line()
		local hash = line:match("^%w+%s+(%w+)")
		if not hash then
			return
		end
		local info = vim.fn.system(
			string.format(
				"git show --stat --pretty=format:'Hash: %%h\nAuthor: %%an\nDate: %%ad\nMessage: %%s\n' %s",
				hash
			)
		)
		if info == "" then
			return
		end
		local float_lines = {}
		for l in info:gmatch("[^\r\n]+") do
			table.insert(float_lines, l)
		end
		local buf = vim.api.nvim_create_buf(false, true)
		local width = math.min(80, math.floor(vim.o.columns * 0.7))
		local height = math.min(20, math.floor(vim.o.lines * 0.3))
		local opts = {
			relative = "editor",
			width = width,
			height = height,
			row = 2,
			col = math.floor((vim.o.columns - width) / 2),
			style = "minimal",
			border = "rounded",
		}
		vim.api.nvim_buf_set_lines(buf, 0, -1, false, float_lines)
		float_win = vim.api.nvim_open_win(buf, false, opts)
		vim.keymap.set("n", "<Esc>", function()
			close_float()
		end, { buffer = buf, nowait = true })
	end

	-- Mapeos buffer-local
	local opts = { noremap = true, silent = true, buffer = true }
	vim.keymap.set("n", "<C-p>", function()
		change_action("pick")
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-s>", function()
		change_action("squash")
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-e>", function()
		change_action("edit")
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-r>", function()
		change_action("reword")
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-d>", function()
		change_action("drop")
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-k>", function()
		move_line(-1)
		apply_highlights()
	end, opts)
	vim.keymap.set("n", "<C-j>", function()
		move_line(1)
		apply_highlights()
	end, opts)
	local function validate_rebase_todo()
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		for i, line in ipairs(lines) do
			local cmd = line:match("^(%w+)")
			if i == 1 and (cmd == "squash" or cmd == "fixup") then
				return false, "First commit cannot be 'squash' or 'fixup'. Change it to 'pick'."
			end
		end
		return true
	end

	vim.keymap.set("n", "<leader>w", function()
		local ok, msg = validate_rebase_todo()
		if not ok then
			vim.api.nvim_echo({ { "[GitWiz] " .. msg, "ErrorMsg" } }, false, {})
			return
		end
		vim.cmd("write")
		local result = vim.fn.system("git rebase --continue")
		vim.api.nvim_echo({ { "[GitWiz] git rebase --continue: " .. result, "Normal" } }, false, {})
		vim.api.nvim_win_close(0, true)
	end, opts)

	vim.keymap.set("n", "<leader>q", function()
		local result = vim.fn.system("git rebase --abort")
		vim.api.nvim_echo({ { "[GitWiz] git rebase --abort: " .. result, "Normal" } }, false, {})
		vim.api.nvim_win_close(0, true)
	end, opts)
	vim.keymap.set("n", "<leader>p", show_commit_floating, opts)

	-- Preview automático al navegar
	vim.api.nvim_create_autocmd("CursorMoved", {
		buffer = 0,
		callback = function()
			apply_highlights()
			show_commit_floating()
		end,
		desc = "GitWiz: auto preview and highlight on move",
	})

	vim.keymap.set("n", "<leader>s", function()
		local result = vim.fn.system("git rebase --skip")
		vim.api.nvim_echo({ { "[GitWiz] git rebase --skip: " .. result, "Normal" } }, false, {})
		vim.api.nvim_win_close(0, true)
	end, opts)

	-- Inicial
	apply_highlights()
	show_commit_floating()
end

local function check_empty_commit()
	local status = vim.fn.system("git status")
	if status:match("nothing to commit, working tree clean") and status:match("rebase") then
		vim.api.nvim_echo({
			{ "[GitWiz] The previous commit is empty after conflict resolution.", "WarningMsg" },
			{ "Use <leader>s to skip this commit and continue the rebase.", "Comment" },
		}, false, {})
	end
end

return M
