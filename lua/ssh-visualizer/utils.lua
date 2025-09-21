-- lua/ssh-viz/utils.lua
-- Utility functions for ssh-viz plugin

local M = {}

-- Get variable name under cursor or visual selection
function M.get_variable_under_cursor()
  local mode = vim.fn.mode()

  if mode == "v" or mode == "V" then
    -- Visual mode - get selected text
    local start_pos = vim.fn.getpos("'<")
    local end_pos = vim.fn.getpos("'>")
    local lines = vim.api.nvim_buf_get_lines(0, start_pos[2] - 1, end_pos[2], false)

    if #lines == 1 then
      return lines[1]:sub(start_pos[3], end_pos[3])
    else
      return table.concat(lines, "\n")
    end
  else
    -- Normal mode - get word under cursor
    return vim.fn.expand("<cword>")
  end
end

-- Send code to REPL via iron.nvim
function M.send_to_repl(code)
  local has_iron, iron = pcall(require, "iron.core")

  if not has_iron then
    vim.notify(
      "iron.nvim not found. Please install iron.nvim for code execution.",
      vim.log.levels.ERROR
    )
    return false
  end

  -- Check if REPL is available
  local repl_bufnr = iron.get_repl_bufnr(vim.bo.filetype)
  if not repl_bufnr or not vim.api.nvim_buf_is_valid(repl_bufnr) then
    vim.notify("No active REPL found. Please start a REPL first.", vim.log.levels.WARN)
    return false
  end

  iron.send(vim.bo.filetype, code)
  return true
end

-- Generate timestamp for file naming
function M.get_timestamp()
  return os.date("%Y%m%d_%H%M%S")
end

-- Generate filename with optional user prefix
function M.generate_filename(base_name, extension, config)
  local filename = base_name

  if config.auto_save.team_prefix then
    local user = vim.fn.system("whoami"):gsub("\n", "")
    filename = user .. "_" .. filename
  end

  if config.auto_save.timestamp then
    filename = filename .. "_" .. M.get_timestamp()
  end

  return filename .. "." .. extension
end

-- Get output directory (shared if available, otherwise local)
function M.get_output_dir(config)
  if config.shared_dir and vim.fn.isdirectory(config.shared_dir) == 1 then
    return config.shared_dir
  else
    return config.output_dir
  end
end

-- Validate variable name (basic Python identifier check)
function M.is_valid_variable_name(name)
  if not name or name == "" then
    return false
  end

  -- Basic check for Python variable name
  return name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") ~= nil
end

-- Escape string for safe insertion into Python code
function M.escape_python_string(str)
  return str:gsub("'", "\\'"):gsub('"', '\\"'):gsub("\n", "\\n")
end

-- Check if server is running on specified port
function M.is_server_running(port)
  local cmd = string.format(
    "netstat -tulpn 2>/dev/null | grep ':%d ' || ss -tulpn 2>/dev/null | grep ':%d '",
    port,
    port
  )
  local result = vim.fn.system(cmd)
  return result and result ~= ""
end

-- Get local IP address for server access instructions
function M.get_local_ip()
  local ip_cmd =
    "hostname -I | awk '{print $1}' || ifconfig | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1"
  local ip = vim.fn.system(ip_cmd):gsub("\n", "")
  return ip ~= "" and ip or "localhost"
end

-- Format server URL for user display
function M.format_server_url(config)
  local ip = M.get_local_ip()
  return string.format("http://%s:%d", ip, config.web_server.port)
end

-- Check Python package availability
function M.check_python_package(package_name)
  local check_code = string.format(
    [[
try:
    import %s
    print("PACKAGE_AVAILABLE:%s")
except ImportError:
    print("PACKAGE_MISSING:%s")
]],
    package_name,
    package_name,
    package_name
  )

  return check_code
end

-- Generate Python setup code for plotting environment
function M.generate_setup_code(config)
  return string.format(
    [[
# ssh-viz plotting setup
import matplotlib
matplotlib.use('%s')
import matplotlib.pyplot as plt
import numpy as np
import os
from datetime import datetime

# Configure matplotlib
plt.rcParams['figure.figsize'] = [%d, %d]
plt.rcParams['figure.dpi'] = %d
plt.rcParams['savefig.dpi'] = %d

try:
    plt.style.use('%s')
except:
    pass  # Fall back to default style

# Ensure output directory exists
os.makedirs('%s', exist_ok=True)

print("ssh-viz plotting environment ready")
]],
    config.matplotlib.backend,
    config.matplotlib.figsize[1],
    config.matplotlib.figsize[2],
    config.matplotlib.dpi,
    config.matplotlib.dpi,
    config.matplotlib.style,
    config.output_dir
  )
end

-- Parse error messages from Python execution
function M.parse_python_error(output)
  if not output then
    return nil
  end

  local lines = vim.split(output, "\n")
  local error_info = {
    type = "Unknown",
    message = "Unknown error",
    traceback = {},
  }

  for _, line in ipairs(lines) do
    if line:match("^Traceback") then
      error_info.type = "Exception"
    elseif line:match("^%w+Error:") then
      error_info.message = line
    elseif line:match("^  File") then
      table.insert(error_info.traceback, line)
    end
  end

  return error_info
end

-- Display formatted error message
function M.show_error(error_info)
  if not error_info then
    return
  end

  local message = string.format("Python Error: %s", error_info.message)
  if #error_info.traceback > 0 then
    message = message .. "\nTraceback: " .. table.concat(error_info.traceback, "\n")
  end

  vim.notify(message, vim.log.levels.ERROR)
end

-- Validate configuration
function M.validate_config(config)
  local errors = {}

  -- Check required fields
  if not config.output_dir or config.output_dir == "" then
    table.insert(errors, "output_dir is required")
  end

  if
    not config.web_server.port
    or config.web_server.port < 1024
    or config.web_server.port > 65535
  then
    table.insert(errors, "web_server.port must be between 1024 and 65535")
  end

  if config.ascii.width < 20 or config.ascii.width > 200 then
    table.insert(errors, "ascii.width should be between 20 and 200")
  end

  if config.ascii.height < 5 or config.ascii.height > 100 then
    table.insert(errors, "ascii.height should be between 5 and 100")
  end

  return #errors == 0, errors
end

-- Debug information gathering
function M.get_debug_info(config)
  local info = {
    plugin_version = "1.0.0",
    nvim_version = vim.version(),
    config = config,
    iron_available = pcall(require, "iron.core"),
    directories = {
      output_exists = vim.fn.isdirectory(config.output_dir) == 1,
      shared_exists = config.shared_dir and vim.fn.isdirectory(config.shared_dir) == 1,
    },
    server_running = M.is_server_running(config.web_server.port),
    local_ip = M.get_local_ip(),
  }

  return info
end

return M