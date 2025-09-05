local log = require("gitwiz.log")
local M = {}

-- Legacy numeric levels (kept for compatibility)
M.levels = {
  DEBUG = 1,
  INFO = 2,
  WARN = 3,
  ERROR = 4,
}

-- Map legacy numeric -> new textual level
local num_to_level = {
  [1] = "debug",
  [2] = "info",
  [3] = "warn",
  [4] = "error",
}

-- Helpers converting vararg to single string (original API accepted ... print-style)
local function join_args(...)
  local parts = {}
  for i, v in ipairs({ ... }) do
    parts[i] = type(v) == "string" and v or vim.inspect(v)
  end
  return table.concat(parts, " ")
end

function M.debug(...)
  log.debug(join_args(...))
end

function M.info(...)
  log.info(join_args(...))
end

function M.warn(...)
  log.warn(join_args(...))
end

function M.error(...)
  log.error(join_args(...))
end

-- Legacy setter accepting either number or string level
function M.set_log_level(level)
  if type(level) == "number" then
    local mapped = num_to_level[level]
    if mapped then log.set_level(mapped) end
  elseif type(level) == "string" then
    log.set_level(level:lower())
  end
end

return M
