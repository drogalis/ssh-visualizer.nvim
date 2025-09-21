if vim.g.loaded_ssh_viz then
  return
end
vim.g.loaded_ssh_viz = 1

-- Auto-setup for Python files
vim.api.nvim_create_autocmd("FileType", {
  pattern = { "python", "quarto", "markdown" },
  callback = function()
    -- Load ssh-viz if not already loaded
    local has_ssh_viz, ssh_viz = pcall(require, "ssh-viz")
    if has_ssh_viz then
      -- Ensure directories exist when opening relevant files
      vim.defer_fn(function()
        local config = ssh_viz.config or {}
        if config.output_dir then
          vim.fn.mkdir(config.output_dir, "p")
        end
      end, 100)
    end
  end,
})

-- Global commands available immediately
vim.api.nvim_create_user_command("SshVizSetup", function()
  local has_ssh_viz, ssh_viz = pcall(require, "ssh-viz")
  if has_ssh_viz then
    ssh_viz.setup()
  else
    vim.notify("ssh-viz not loaded. Check your plugin configuration.", vim.log.levels.ERROR)
  end
end, { desc = "Setup ssh-viz plugin" })

vim.api.nvim_create_user_command("SshVizInfo", function()
  local has_ssh_viz, ssh_viz = pcall(require, "ssh-viz")
  if has_ssh_viz then
    local utils = require("ssh-viz.utils")
    local info = utils.get_debug_info(ssh_viz.config or {})

    print("ssh-viz Plugin Information:")
    print("==========================")
    print("Version: " .. info.plugin_version)
    print("Neovim: " .. tostring(info.nvim_version))
    print("Iron.nvim available: " .. tostring(info.iron_available))
    print("Output directory exists: " .. tostring(info.directories.output_exists))
    print("Shared directory exists: " .. tostring(info.directories.shared_exists or false))
    print("Server running: " .. tostring(info.server_running))
    print("Local IP: " .. info.local_ip)
  else
    vim.notify("ssh-viz not loaded", vim.log.levels.WARN)
  end
end, { desc = "Show ssh-viz plugin information" })