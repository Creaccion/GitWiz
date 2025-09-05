-- core/runner.lua
local log = require("gitwiz.log")
local config = require("gitwiz.core.config")

local M = {}
local metrics = { git_calls = 0 }

-- Split keeping empty lines (important for parsers that rely on blank separators)
local function split_lines(s)
  local t = {}
  if not s or s == "" then
    return t
  end
  -- Append newline to capture last line even if not newline-terminated
  for line in (s .. "\n"):gmatch("(.-)\n") do
    -- keep line as-is (can be empty string)
    t[#t+1] = line
  end
  return t
end

--- Run a git command synchronously.
-- NOTE: stdout and stderr are not separated with vim.fn.system.
-- Failure sets stderr = combined output (limitation to improve later).
-- @param args string[]
-- @param opts table|nil
function M.run(args, opts)
  metrics.git_calls = metrics.git_calls + 1
  local cmd = { "git" }
  vim.list_extend(cmd, args)
  local start = vim.loop.hrtime()
  local out = vim.fn.system(cmd)
  local code = vim.v.shell_error
  local duration = (vim.loop.hrtime() - start) / 1e6
  local ok = code == 0
  if not ok then
    log.debug("git failed: " .. table.concat(cmd, " ") .. " exit=" .. code)
  end
  return {
    ok = ok,
    code = code,
    cmd = cmd,
    stdout = out,
    stderr = ok and "" or out,
    stdout_lines = split_lines(out),
    duration_ms = duration,
    opts = opts,
  }
end

function M.metrics()
  return vim.deepcopy(metrics)
end

return M
