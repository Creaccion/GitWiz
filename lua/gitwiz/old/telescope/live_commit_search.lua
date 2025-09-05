local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local previewers = require('telescope.previewers')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')
local commit_actions = require("gitwiz.actions.commit")
local debug = require("gitwiz.config.debug")

local max_results = 500

local function format_header(entry, commit_details)
  local header = {}
  table.insert(header, " Commit: " .. (entry.hash:sub(1, 7)))
  table.insert(header, " Message: " .. (entry.message or ""))
  if commit_details then
    table.insert(header, " Author: " .. (commit_details.author or ""))
    table.insert(header, " Date:   " .. (commit_details.date or ""))
  end
  table.insert(header, string.rep("-", 60))
  return header
end

local previewer = previewers.new_buffer_previewer {
  define_preview = function(self, entry)
    if not entry or not entry.value then
      vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, { "No entry selected." })
      return
    end

    local hash = entry.value.hash
    local file = entry.value.file
    local ok, details = commit_actions.get_commit_details(hash)

    -- Header with commit details
    local header = {}
    table.insert(header, " Commit: " .. hash:sub(1, 7))
    table.insert(header, " Message: " .. (entry.value.message or ""))
    if ok and details then
      table.insert(header, " Author: " .. (details.author or ""))
      table.insert(header, " Date:   " .. (details.date or ""))
    end
    table.insert(header, string.rep("-", 60))
    table.insert(header, string.rep(" ", 60))

    table.insert(header, string.rep("-", 60))

    table.insert(header, "FILE: " .. file)
    table.insert(header, string.rep("-", 60))
    -- Read file content using `git_show`
    local file_content = {}
    if file then
      local success, result = commit_actions.git_show(hash, file)
      if success then
        file_content = result
      else
        file_content = result -- Result contains the error message
      end
    else
      table.insert(file_content, "No file specified.")
    end

    -- Combine header and file content
    local preview_content = vim.list_extend(header, file_content)
    vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, preview_content)
  end,
}


local function live_commit_search_S()
  pickers.new({}, {
    prompt_title = "GitWiz: Live Search Commits (-S, content change)",
    finder = finders.new_job(function(prompt)
      if not prompt or prompt == "" then
        return nil
      end
      local cmd = {
        "git", "log", "--all", "-S" .. prompt, "--oneline", "--decorate=short", "--reverse", "--name-only"
      }
      return cmd
    end, (function()
      -- Closure to maintain the state of `last_commit`
      local last_commit = nil

      return function(line)
        if not line or line == "" or line:match("^%s*$") then
          return nil
        end

        -- Detect commit lines and file lines
        local hash, message = line:match("^(%w+)%s(.+)$")
        if hash then
          -- Start a new commit entry
          last_commit = {
            hash = hash,
            message = message,
          }
          return nil
        elseif last_commit then
          -- Create a new entry for each file
          local entry = {
            value = { hash = last_commit.hash, message = last_commit.message, file = line },
            display = string.format("%s %s [%s]", last_commit.hash:sub(1, 7), last_commit.message, line),
            ordinal = string.format("%s %s %s", last_commit.hash, last_commit.message, line),
          }
          return entry
        end
      end
    end)(), max_results),
    sorter = require('telescope.sorters').Sorter:new {
      scoring_function = function() return 0 end,
      highlighter = function() return {} end,
    },
    previewer = previewer,
    layout_strategy = "vertical",
    layout_config = { preview_height = 0.6 },
    default_selection_index = 1,
    attach_mappings = function(prompt_bufnr, map)
      map("i", "<CR>", function()
        local actions_state = require("telescope.actions.state")
        local selection = actions_state.get_selected_entry()

        -- Depuración: Verificar la selección

        if not selection or not selection.value then
          print("Error: No selection made")
          return
        end

        local hash = selection.value.hash
        local file = selection.value.file

        -- Depuración: Verificar hash y archivo
        print("File:", file)

        -- Ejecutar las acciones en un contexto seguro
        vim.schedule(function()
          -- Depuración: Verificar commit details
          local ok, details = commit_actions.get_commit_file_details(hash, file)
          if not ok or not details then
            print("Error: Unable to fetch commit details")
            return
          end

          -- Depuración: Verificar detalles del commit

          if details.diff then
            vim.cmd("new")
            vim.api.nvim_buf_set_lines(0, 0, -1, false, details.diff)
            vim.bo.buftype = "nofile"
            vim.bo.bufhidden = "hide" -- Cambiado de 'wipe' a 'hide'
            vim.bo.swapfile = false
            vim.bo.filetype = "diff"
            vim.api.nvim_buf_set_name(0, string.format("diff@%s:%s", hash:sub(1, 7), file))

            -- Depuración: Confirmar que el buffer se creó
          else
            print("Error: No diff available for commit:", hash)
          end
        end)

        -- Cerrar el picker después de programar las acciones
        require("telescope.actions").close(prompt_bufnr)
      end)
      return true
    end,
  }):find()
end

return {
  live_commit_search_S = live_commit_search_S
}
