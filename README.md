# ssh-visualizer.nvim

A Neovim plugin for visualizing matplotlib plots and data analysis results in SSH/remote environments where traditional image display is challenging.

## Features

- **ASCII plots** for immediate terminal feedback
- **Web-based visualization** via built-in HTTP server
- **Matplotlib integration** with automatic plot generation
- **Shared directory support** for team environments
- **SSH-friendly** design for remote development
- **Quantitative finance** optimized templates

## Use Cases

- Data science on remote servers
- Quantitative finance analysis via SSH
- Terminal-based data exploration
- Collaborative analysis with shared plots
- Jupyter notebook alternatives in vim

## Installation

### Using [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "your-username/ssh-viz.nvim",
  dependencies = {
    "Vigemus/iron.nvim", -- Required for code execution
  },
  ft = { "python", "quarto", "markdown" },
  config = function()
    require("ssh-viz").setup({
      -- Optional configuration
      output_dir = "/tmp/nvim_plots",
      shared_dir = nil, -- Set to shared mount point if available
      web_server = {
        host = "0.0.0.0",
        port = 8888,
        auto_open = false,
      },
      ascii = {
        width = 80,
        height = 24,
        use_unicode = true,
      },
    })
  end,
}
```

### Using [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "your-username/ssh-viz.nvim",
  requires = { "Vigemus/iron.nvim" },
  ft = { "python", "quarto", "markdown" },
  config = function()
    require("ssh-viz").setup()
  end,
}
```

## Requirements

### Server-side Python packages

```bash
pip install matplotlib textplots plotext numpy pandas
```

### Optional for enhanced ASCII plots

```bash
pip install rich plotly kaleido
```

## Quick Start

1. **Setup iron.nvim REPL**: `<leader>io` (or your iron.nvim keymap)
2. **Create some data**:
   ```python
   import numpy as np
   data = np.random.randn(100).cumsum()
   ```
3. **Visualize**:
   - `<leader>vv` (quick plot variable under cursor)
   - `<leader>va` (ASCII plot in terminal)
   - `<leader>vl` (web-based line plot)

## Keymaps

| Keymap       | Action       | Description                |
| ------------ | ------------ | -------------------------- |
| `<leader>vv` | Quick plot   | Plot variable under cursor |
| `<leader>vl` | Line plot    | Interactive line chart     |
| `<leader>vs` | Scatter plot | Scatter chart              |
| `<leader>vh` | Histogram    | Distribution plot          |
| `<leader>va` | ASCII plot   | Terminal-based plot        |
| `<leader>vS` | Start server | Launch HTTP server         |
| `<leader>vo` | Open plots   | Open plot directory        |

## Usage Examples

### Basic Plotting

```python
# Create data
import numpy as np
prices = np.random.randn(252).cumsum() + 100

# Plot with cursor on 'prices' variable
# Press <leader>vv for quick plot
```

### Financial Analysis

```python
# Risk analysis
returns = np.diff(np.log(prices))
volatility = returns.rolling(20).std() * np.sqrt(252)

# Position cursor on 'volatility' and press <leader>vl
```

### ASCII Plots for Quick Exploration

```python
# Immediate feedback in terminal
# Press <leader>va on any numeric variable
portfolio_values = [100, 102, 98, 105, 103]
```

## Configuration

### Full Configuration Example

```lua
require("ssh-viz").setup({
  -- Plot output directory
  output_dir = "/tmp/nvim_plots",

  -- Shared directory for team collaboration
  shared_dir = "/mnt/shared/analysis_plots",

  -- Web server settings
  web_server = {
    host = "0.0.0.0",        -- Bind to all interfaces
    port = 8888,             -- Server port
    auto_open = false,       -- Don't auto-open browser
    cors_enabled = true,     -- Enable CORS for remote access
  },

  -- ASCII plot settings
  ascii = {
    width = 100,             -- Plot width in characters
    height = 30,             -- Plot height in characters
    use_unicode = true,      -- Use Unicode characters
    style = "braille",       -- "braille", "block", or "ascii"
  },

  -- Matplotlib settings
  matplotlib = {
    backend = "Agg",         -- Non-interactive backend
    dpi = 150,               -- High resolution
    figsize = {10, 6},       -- Default figure size
    style = "seaborn-v0_8",  -- Plot style
  },

  -- Auto-save settings
  auto_save = {
    enabled = true,
    formats = {"png", "html", "svg"},
    timestamp = true,
  },
})
```

### Environment-Specific Configs

#### High-Security Environment

```lua
require("ssh-viz").setup({
  web_server = {
    host = "127.0.0.1",  -- Localhost only
    port = 8888,
    auth_required = true,
  },
  shared_dir = nil,  -- No shared directories
})
```

#### Team Collaboration

```lua
require("ssh-viz").setup({
  shared_dir = "/nfs/team/plots",
  web_server = {
    host = "0.0.0.0",
    port = 8888,
    cors_enabled = true,
  },
  auto_save = {
    formats = {"png", "html", "pdf"},
    team_prefix = true,  -- Add username to filenames
  },
})
```

## Advanced Usage

### Custom Plot Templates

```lua
-- Create custom financial plot
vim.keymap.set("n", "<leader>vr", function()
  local var = vim.fn.input("Returns variable: ")
  local code = string.format([[
import matplotlib.pyplot as plt
import numpy as np

# Risk-return scatter
plt.figure(figsize=(12, 8))
plt.scatter(np.std(%s), np.mean(%s), alpha=0.7)
plt.xlabel('Volatility')
plt.ylabel('Expected Return')
plt.title('Risk-Return Profile')
plt.grid(True)

# Save plot
plt.savefig('/tmp/nvim_plots/risk_return.png', dpi=150, bbox_inches='tight')
plt.close()
print("Risk-return plot saved")
]], var, var)

  require("iron.core").send(vim.bo.filetype, code)
end, { desc = "Risk-return plot" })
```

### Integration with Existing Workflows

```lua
-- Auto-start plot server when opening Python files
vim.api.nvim_create_autocmd("FileType", {
  pattern = "python",
  callback = function()
    if vim.fn.has("python3") == 1 then
      vim.defer_fn(function()
        require("ssh-viz").ensure_server_running()
      end, 1000)
    end
  end,
})
```

## Troubleshooting

### Common Issues

**Plot server not accessible**

- Check firewall settings: `sudo ufw allow 8888`
- Verify server is running: `netstat -tulpn | grep :8888`
- Try different port in configuration

**ASCII plots not displaying**

- Install required packages: `pip install textplots plotext`
- Check terminal Unicode support
- Try `ascii = { use_unicode = false }` in config

**Permission errors**

- Ensure output directory is writable: `chmod 755 /tmp/nvim_plots`
- Check shared directory permissions if using team features

**Iron.nvim integration issues**

- Verify iron.nvim is properly configured
- Ensure Python REPL is active before plotting
- Check `:IronInfo` for connection status

### Performance Tips

- Use `auto_save = { enabled = false }` for large datasets
- Set `matplotlib = { dpi = 100 }` for faster rendering
- Configure `shared_dir` on fast storage (SSD)

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Submit a pull request

### Development Setup

```bash
git clone https://github.com/your-username/ssh-viz.nvim
cd ssh-viz.nvim
```

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built for the quantitative finance and data science communities
- Inspired by Jupyter notebook workflows
- Designed for SSH/remote development environments