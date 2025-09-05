
local M = {}

local default_config = {
  level = "info",
  use_notify = true,
  plugin_name = "GitWiz",
  max_len = 800,
  levels = { trace = 0, debug = 1, info = 2, warn = 3, error = 4 },
}

local config

function M.setup(opts)
  config = vim.tbl_deep_extend("force", default_config, opts or {})
end

local function should_log(level)
  local cur = config.levels[config.level] or 1
  local target = config.levels[level] or 1
  return target >= cur
end

local function format_msg(msg, ctx)
  if ctx and type(ctx) == "table" then
    local ok, json = pcall(vim.json.encode, ctx)
    if ok then
      return msg .. " | ctx=" .. json
    end
  end
  return msg
end

local function emit(level, msg, ctx)
  if not config then M.setup() end
  if not should_log(level) then return end
  local out = format_msg(msg, ctx)
  if #out > config.max_len then
    out = out:sub(1, config.max_len) .. "...(truncated)"
  end
  local prefix = string.format("[%s][%s]", config.plugin_name, level:upper())
  if config.use_notify and vim.notify then
    local map = {
      trace = vim.log.levels.DEBUG,
      debug = vim.log.levels.DEBUG,
      info  = vim.log.levels.INFO,
      warn  = vim.log.levels.WARN,
      error = vim.log.levels.ERROR,
    }
    vim.notify(prefix .. " " .. out, map[level] or vim.log.levels.INFO)
  else
    print(prefix .. " " .. out)
  end
end

for _, lvl in ipairs({ "trace", "debug", "info", "warn", "error" }) do
  M[lvl] = function(msg, ctx) emit(lvl, msg, ctx) end
end

function M.set_level(level)
  if config.levels[level] then
    config.level = level
  end
end

function M.get_level()
  return config and config.level or default_config.level
end

return M
