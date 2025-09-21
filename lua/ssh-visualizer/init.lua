-- lua/ssh-viz/init.lua
-- Main plugin entry point for ssh-viz.nvim

local M = {}

-- Default configuration
M.config = {
  -- Plot output directory
  output_dir = "/tmp/nvim_plots",

  -- Shared directory for team collaboration (nil = disabled)
  shared_dir = nil,

  -- Web server configuration
  web_server = {
    host = "0.0.0.0",
    port = 8888,
    auto_open = false,
    cors_enabled = true,
  },

  -- ASCII plot settings
  ascii = {
    width = 80,
    height = 24,
    use_unicode = true,
    style = "braille", -- "braille", "block", "ascii"
  },

  -- Matplotlib configuration
  matplotlib = {
    backend = "Agg",
    dpi = 150,
    figsize = { 10, 6 },
    style = "seaborn-v0_8",
  },

  -- Auto-save settings
  auto_save = {
    enabled = true,
    formats = { "png", "html" },
    timestamp = true,
    team_prefix = false,
  },

  -- Keymaps configuration
  keymaps = {
    prefix = "<leader>v",
    quick_plot = "v",
    line_plot = "l",
    scatter_plot = "s",
    histogram = "h",
    ascii_plot = "a",
    start_server = "S",
    open_plots = "o",
  },
}

-- Internal state
M._server_running = false
M._server_job = nil

-- Utility functions
local utils = require("ssh-viz.utils")
local plots = require("ssh-viz.plots")
local server = require("ssh-viz.server")

-- Ensure plot directories exist
local function ensure_directories()
  if vim.fn.isdirectory(M.config.output_dir) == 0 then
    vim.fn.mkdir(M.config.output_dir, "p")
  end

  if M.config.shared_dir and vim.fn.isdirectory(M.config.shared_dir) == 0 then
    local success = pcall(vim.fn.mkdir, M.config.shared_dir, "p")
    if not success then
      vim.notify(
        "Warning: Could not create shared directory: " .. M.config.shared_dir,
        vim.log.levels.WARN
      )
      M.config.shared_dir = nil
    end
  end
end

-- Check dependencies
local function check_dependencies()
  local missing = {}

  -- Check for iron.nvim
  local has_iron, _ = pcall(require, "iron.core")
  if not has_iron then
    table.insert(missing, "iron.nvim (required for code execution)")
  end

  -- Check Python packages (will be verified when first used)
  local python_check = [[
import sys
packages = ['matplotlib', 'numpy']
missing = []
for pkg in packages:
    try:
        __import__(pkg)
    except ImportError:
        missing.append(pkg)

if missing:
    print(f"Missing Python packages: {', '.join(missing)}")
    print("Install with: pip install " + " ".join(missing))
else:
    print("Python dependencies satisfied")
]]

  if #missing > 0 then
    vim.notify(
      "ssh-viz.nvim missing dependencies:\n" .. table.concat(missing, "\n"),
      vim.log.levels.WARN
    )
    return false
  end

  return true
end

-- Main plot functions
function M.plot_line(data_var)
  data_var = data_var or utils.get_variable_under_cursor()
  if not data_var or data_var == "" then
    vim.notify("No variable specified for plotting", vim.log.levels.WARN)
    return
  end

  ensure_directories()
  local code = plots.generate_line_plot(data_var, M.config)
  utils.send_to_repl(code)
end

function M.plot_scatter(data_var)
  data_var = data_var or utils.get_variable_under_cursor()
  if not data_var or data_var == "" then
    vim.notify("No variable specified for plotting", vim.log.levels.WARN)
    return
  end

  ensure_directories()
  local code = plots.generate_scatter_plot(data_var, M.config)
  utils.send_to_repl(code)
end

function M.plot_histogram(data_var)
  data_var = data_var or utils.get_variable_under_cursor()
  if not data_var or data_var == "" then
    vim.notify("No variable specified for plotting", vim.log.levels.WARN)
    return
  end

  ensure_directories()
  local code = plots.generate_histogram(data_var, M.config)
  utils.send_to_repl(code)
end

function M.plot_ascii(data_var)
  data_var = data_var or utils.get_variable_under_cursor()
  if not data_var or data_var == "" then
    vim.notify("No variable specified for plotting", vim.log.levels.WARN)
    return
  end

  local code = plots.generate_ascii_plot(data_var, M.config)
  utils.send_to_repl(code)
end

-- Server management
function M.start_server()
  if M._server_running then
    vim.notify("Plot server is already running", vim.log.levels.INFO)
    return
  end

  ensure_directories()
  local code = server.generate_server_code(M.config)
  utils.send_to_repl(code)

  M._server_running = true
  vim.notify(
    string.format(
      "Plot server starting on http://%s:%d",
      M.config.web_server.host,
      M.config.web_server.port
    ),
    vim.log.levels.INFO
  )
end

function M.stop_server()
  if not M._server_running then
    vim.notify("No plot server is running", vim.log.levels.INFO)
    return
  end

  -- Send interrupt to stop server
  utils.send_to_repl("import os; os._exit(0)")
  M._server_running = false
  vim.notify("Plot server stopped", vim.log.levels.INFO)
end

function M.ensure_server_running()
  if not M._server_running then
    M.start_server()
  end
end

function M.open_plot_directory()
  local dir = M.config.shared_dir or M.config.output_dir
  if vim.fn.isdirectory(dir) == 1 then
    vim.cmd("edit " .. dir)
  else
    vim.notify("Plot directory does not exist: " .. dir, vim.log.levels.WARN)
  end
end

-- Interactive plotting with prompts
function M.interactive_plot()
  local plot_types = { "line", "scatter", "histogram", "ascii" }

  vim.ui.select(plot_types, {
    prompt = "Select plot type:",
  }, function(choice)
    if not choice then
      return
    end

    local var = vim.fn.input("Variable to plot: ", utils.get_variable_under_cursor())
    if var == "" then
      return
    end

    if choice == "line" then
      M.plot_line(var)
    elseif choice == "scatter" then
      M.plot_scatter(var)
    elseif choice == "histogram" then
      M.plot_histogram(var)
    elseif choice == "ascii" then
      M.plot_ascii(var)
    end
  end)
end

-- Setup keymaps
local function setup_keymaps()
  local prefix = M.config.keymaps.prefix
  local km = M.config.keymaps

  -- Main plotting functions
  vim.keymap.set("n", prefix .. km.quick_plot, function()
    M.plot_line()
  end, { desc = "Quick plot variable under cursor" })

  vim.keymap.set("n", prefix .. km.line_plot, function()
    local var = vim.fn.input("Variable to plot: ", utils.get_variable_under_cursor())
    if var ~= "" then
      M.plot_line(var)
    end
  end, { desc = "Line plot with prompt" })

  vim.keymap.set("n", prefix .. km.scatter_plot, function()
    local var = vim.fn.input("Variable for scatter plot: ", utils.get_variable_under_cursor())
    if var ~= "" then
      M.plot_scatter(var)
    end
  end, { desc = "Scatter plot with prompt" })

  vim.keymap.set("n", prefix .. km.histogram, function()
    local var = vim.fn.input("Variable for histogram: ", utils.get_variable_under_cursor())
    if var ~= "" then
      M.plot_histogram(var)
    end
  end, { desc = "Histogram with prompt" })

  vim.keymap.set("n", prefix .. km.ascii_plot, function()
    local var = vim.fn.input("Variable for ASCII plot: ", utils.get_variable_under_cursor())
    if var ~= "" then
      M.plot_ascii(var)
    end
  end, { desc = "ASCII plot with prompt" })

  -- Server management
  vim.keymap.set("n", prefix .. km.start_server, M.start_server, { desc = "Start plot server" })
  vim.keymap.set(
    "n",
    prefix .. km.open_plots,
    M.open_plot_directory,
    { desc = "Open plot directory" }
  )

  -- Interactive plotting
  vim.keymap.set("n", prefix .. "i", M.interactive_plot, { desc = "Interactive plot menu" })
end

-- Setup user commands
local function setup_commands()
  vim.api.nvim_create_user_command(
    "SshVizStart",
    M.start_server,
    { desc = "Start ssh-viz plot server" }
  )
  vim.api.nvim_create_user_command(
    "SshVizStop",
    M.stop_server,
    { desc = "Stop ssh-viz plot server" }
  )
  vim.api.nvim_create_user_command(
    "SshVizPlot",
    M.interactive_plot,
    { desc = "Interactive plotting menu" }
  )
  vim.api.nvim_create_user_command(
    "SshVizOpen",
    M.open_plot_directory,
    { desc = "Open plot directory" }
  )
end

-- Main setup function
function M.setup(opts)
  -- Merge user configuration
  M.config = vim.tbl_deep_extend("force", M.config, opts or {})

  -- Check dependencies
  if not check_dependencies() then
    return
  end

  -- Create directories
  ensure_directories()

  -- Setup keymaps and commands
  setup_keymaps()
  setup_commands()

  -- Auto-start server if configured
  if M.config.web_server.auto_start then
    vim.defer_fn(function()
      M.start_server()
    end, 1000)
  end

  vim.notify("ssh-viz.nvim loaded successfully", vim.log.levels.INFO)
end

return M