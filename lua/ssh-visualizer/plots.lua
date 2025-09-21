-- lua/ssh-viz/plots.lua
-- Plot generation functions for ssh-viz plugin

local utils = require("ssh-viz.utils")
local M = {}

-- Generate HTML template for web plots
local function generate_html_template(title, plot_data, timestamp)
  return string.format(
    [[
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>%s</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background-color: #f8f9fa;
            color: #212529;
        }
        .container {
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 8px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            padding: 30px;
        }
        .header {
            border-bottom: 2px solid #e9ecef;
            margin-bottom: 20px;
            padding-bottom: 20px;
        }
        .plot-image {
            max-width: 100%%;
            height: auto;
            border-radius: 4px;
            box-shadow: 0 1px 3px rgba(0,0,0,0.1);
        }
        .metadata {
            margin-top: 20px;
            padding: 15px;
            background-color: #f8f9fa;
            border-radius: 4px;
            font-size: 0.9em;
            color: #6c757d;
        }
        .refresh-btn {
            background: #007bff;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            margin-top: 10px;
        }
        .refresh-btn:hover {
            background: #0056b3;
        }
    </style>
    <script>
        function refreshPlot() {
            location.reload();
        }
        // Auto-refresh every 30 seconds
        setTimeout(function() {
            location.reload();
        }, 30000);
    </script>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>%s</h1>
            <button class="refresh-btn" onclick="refreshPlot()">Refresh Plot</button>
        </div>
        <img src="data:image/png;base64,%s" alt="Plot" class="plot-image">
        <div class="metadata">
            <strong>Generated:</strong> %s<br>
            <strong>Auto-refresh:</strong> Every 30 seconds<br>
            <strong>Source:</strong> ssh-viz.nvim
        </div>
    </div>
</body>
</html>
]],
    title,
    title,
    plot_data,
    timestamp
  )
end

-- Base plotting template
local function generate_base_plot_code(data_var, plot_type, config, custom_code)
  local output_dir = utils.get_output_dir(config)
  local timestamp = utils.get_timestamp()
  local filename_base = utils.generate_filename("plot", "png", config)
  local html_filename = utils.generate_filename("plot", "html", config)

  return string.format(
    [[
# ssh-viz %s plot
import matplotlib
matplotlib.use('%s')
import matplotlib.pyplot as plt
import numpy as np
from io import BytesIO
import base64
from datetime import datetime
import os

# Ensure output directory exists
os.makedirs('%s', exist_ok=True)

try:
    # Validate data
    data = np.array(%s)
    if data.size == 0:
        raise ValueError("Data array is empty")

    # Configure plot
    plt.figure(figsize=(%d, %d))
    plt.rcParams['figure.dpi'] = %d

    %s

    # Enhance plot appearance
    plt.grid(True, alpha=0.3)
    plt.tight_layout()

    # Save as PNG
    png_path = '%s/%s'
    plt.savefig(png_path, dpi=%d, bbox_inches='tight',
                facecolor='white', edgecolor='none')

    # Generate base64 for HTML
    buffer = BytesIO()
    plt.savefig(buffer, format='png', dpi=%d, bbox_inches='tight',
                facecolor='white', edgecolor='none')
    buffer.seek(0)
    plot_data = base64.b64encode(buffer.read()).decode()
    plt.close()

    # Generate HTML
    html_content = '''%s'''

    html_path = '%s/%s'
    with open(html_path, 'w') as f:
        f.write(html_content)

    print(f"✓ Plot saved: {png_path}")
    print(f"✓ HTML saved: {html_path}")
    print(f"✓ View at: http://localhost:%d/{html_filename}")

except Exception as e:
    print(f"✗ Plot error: {e}")
    import traceback
    traceback.print_exc()
]],
    plot_type,
    config.matplotlib.backend,
    output_dir,
    data_var,
    config.matplotlib.figsize[1],
    config.matplotlib.figsize[2],
    config.matplotlib.dpi,
    custom_code,
    output_dir,
    filename_base,
    config.matplotlib.dpi,
    config.matplotlib.dpi,
    generate_html_template(
      plot_type:gsub("^%l", string.upper) .. " Plot",
      "{plot_data}",
      datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    ):gsub("'", "\\'"),
    output_dir,
    html_filename,
    config.web_server.port,
    html_filename
  )
end

-- Line plot generation
function M.generate_line_plot(data_var, config)
  local plot_code = [[
    # Line plot
    if data.ndim == 1:
        plt.plot(data, linewidth=2, alpha=0.8)
        plt.title(f'Line Plot: {data_var}')
        plt.xlabel('Index')
        plt.ylabel('Value')
    elif data.ndim == 2 and data.shape[1] == 2:
        plt.plot(data[:, 0], data[:, 1], linewidth=2, alpha=0.8)
        plt.title(f'Line Plot: {data_var}')
        plt.xlabel('X')
        plt.ylabel('Y')
    else:
        # Multiple series
        for i in range(min(data.shape[1] if data.ndim > 1 else 1, 10)):
            if data.ndim == 1:
                plt.plot(data, label=f'{data_var}', linewidth=2, alpha=0.8)
                break
            else:
                plt.plot(data[:, i], label=f'{data_var}[{i}]', linewidth=2, alpha=0.8)
        if data.ndim > 1 and data.shape[1] > 1:
            plt.legend()
        plt.title(f'Line Plot: {data_var}')
        plt.xlabel('Index')
        plt.ylabel('Value')
  ]]

  return generate_base_plot_code(data_var, "line", config, plot_code)
end

-- Scatter plot generation
function M.generate_scatter_plot(data_var, config)
  local plot_code = [[
    # Scatter plot
    if data.ndim == 1:
        plt.scatter(range(len(data)), data, alpha=0.6, s=30)
        plt.title(f'Scatter Plot: {data_var}')
        plt.xlabel('Index')
        plt.ylabel('Value')
    elif data.ndim == 2 and data.shape[1] >= 2:
        plt.scatter(data[:, 0], data[:, 1], alpha=0.6, s=30)
        plt.title(f'Scatter Plot: {data_var}')
        plt.xlabel('X')
        plt.ylabel('Y')
    else:
        plt.scatter(range(len(data.flatten())), data.flatten(), alpha=0.6, s=30)
        plt.title(f'Scatter Plot: {data_var}')
        plt.xlabel('Index')
        plt.ylabel('Value')
  ]]

  return generate_base_plot_code(data_var, "scatter", config, plot_code)
end

-- Histogram generation
function M.generate_histogram(data_var, config)
  local plot_code = [[
    # Histogram
    data_flat = data.flatten()
    plt.hist(data_flat, bins=min(30, max(5, len(data_flat)//10)),
             alpha=0.7, edgecolor='black', linewidth=0.5)
    plt.title(f'Histogram: {data_var}')
    plt.xlabel('Value')
    plt.ylabel('Frequency')

    # Add statistics
    mean_val = np.mean(data_flat)
    std_val = np.std(data_flat)
    plt.axvline(mean_val, color='red', linestyle='--', alpha=0.8,
                label=f'Mean: {mean_val:.3f}')
    plt.axvline(mean_val + std_val, color='orange', linestyle='--', alpha=0.6,
                label=f'Mean + Std: {mean_val + std_val:.3f}')
    plt.axvline(mean_val - std_val, color='orange', linestyle='--', alpha=0.6,
                label=f'Mean - Std: {mean_val - std_val:.3f}')
    plt.legend()
  ]]

  return generate_base_plot_code(data_var, "histogram", config, plot_code)
end

-- ASCII plot generation
function M.generate_ascii_plot(data_var, config)
  local width = config.ascii.width
  local height = config.ascii.height
  local use_unicode = config.ascii.use_unicode and "True" or "False"

  return string.format(
    [[
# ssh-viz ASCII plot
try:
    import numpy as np
    data = np.array(%s)

    # Try plotext first (better ASCII plots)
    try:
        import plotext as plt
        plt.clear_data()
        plt.plot(data.flatten())
        plt.title('%s - ASCII Plot')
        plt.show()

    except ImportError:
        # Fallback to textplots
        try:
            from textplots import plot
            print("\\n" + "="*%d)
            print("ASCII PLOT: %s")
            print("="*%d)
            plot(data.flatten(), width=%d, height=%d)
            print("="*%d + "\\n")

        except ImportError:
            # Manual ASCII plot as last resort
            data_flat = data.flatten()
            min_val, max_val = np.min(data_flat), np.max(data_flat)

            print("\\n" + "="*%d)
            print("ASCII PLOT: %s")
            print("="*%d)

            # Simple ASCII representation
            for i in range(%d):
                row_val = max_val - (i / %d) * (max_val - min_val)
                line = "|"
                for j, val in enumerate(data_flat[:min(len(data_flat), %d)]):
                    if abs(val - row_val) < (max_val - min_val) / %d:
                        line += "*" if %s else "#"
                    else:
                        line += " "
                print(line)

            # X-axis
            print("+" + "-" * min(len(data_flat), %d))
            print(f"Range: {min_val:.3f} to {max_val:.3f}")
            print("="*%d + "\\n")

            print("Install better ASCII plotting: pip install plotext textplots")

except Exception as e:
    print(f"ASCII plot error: {e}")
]],
    data_var,
    data_var,
    width,
    data_var,
    width,
    width,
    height,
    width,
    width,
    data_var,
    width,
    height,
    height,
    width,
    height,
    use_unicode,
    width,
    width
  )
end

-- Financial-specific plot templates
function M.generate_returns_plot(data_var, config)
  local plot_code = string.format(
    [[
    # Financial returns analysis
    returns = np.array(%s)

    # Create subplot layout
    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

    # Price series (cumulative returns)
    cumulative = np.cumprod(1 + returns)
    ax1.plot(cumulative, linewidth=2)
    ax1.set_title('Cumulative Returns')
    ax1.grid(True, alpha=0.3)

    # Returns distribution
    ax2.hist(returns, bins=50, alpha=0.7, edgecolor='black')
    ax2.axvline(np.mean(returns), color='red', linestyle='--', label='Mean')
    ax2.set_title('Returns Distribution')
    ax2.legend()
    ax2.grid(True, alpha=0.3)

    # Rolling volatility
    window = min(20, len(returns)//4)
    rolling_vol = pd.Series(returns).rolling(window).std() * np.sqrt(252)
    ax3.plot(rolling_vol, linewidth=2, color='orange')
    ax3.set_title(f'Rolling Volatility ({window}d)')
    ax3.grid(True, alpha=0.3)

    # Q-Q plot for normality
    from scipy import stats
    stats.probplot(returns, dist="norm", plot=ax4)
    ax4.set_title('Q-Q Plot (Normality Test)')
    ax4.grid(True, alpha=0.3)

    plt.tight_layout()
  ]],
    data_var
  )

  return generate_base_plot_code(data_var, "returns_analysis", config, plot_code)
end

function M.generate_risk_plot(data_var, config)
  local plot_code = string.format(
    [[
    # Risk analysis plot
    data = np.array(%s)

    # Risk metrics
    returns = np.diff(np.log(data)) if len(data) > 1 else data

    fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(15, 10))

    # Value at Risk
    var_95 = np.percentile(returns, 5)
    var_99 = np.percentile(returns, 1)

    ax1.hist(returns, bins=50, alpha=0.7, edgecolor='black')
    ax1.axvline(var_95, color='orange', linestyle='--', label='VaR 95%%')
    ax1.axvline(var_99, color='red', linestyle='--', label='VaR 99%%')
    ax1.set_title('Value at Risk')
    ax1.legend()
    ax1.grid(True, alpha=0.3)

    # Drawdown
    cumulative = np.cumprod(1 + returns)
    running_max = np.maximum.accumulate(cumulative)
    drawdown = (cumulative - running_max) / running_max

    ax2.fill_between(range(len(drawdown)), drawdown, 0, alpha=0.3, color='red')
    ax2.plot(drawdown, color='red', linewidth=1)
    ax2.set_title('Drawdown')
    ax2.grid(True, alpha=0.3)

    # Rolling Sharpe ratio
    window = min(60, len(returns)//3)
    rolling_sharpe = pd.Series(returns).rolling(window).mean() / pd.Series(returns).rolling(window).std() * np.sqrt(252)
    ax3.plot(rolling_sharpe, linewidth=2, color='green')
    ax3.set_title(f'Rolling Sharpe Ratio ({window}d)')
    ax3.grid(True, alpha=0.3)

    # Risk-return scatter
    if len(returns) > 20:
        chunks = np.array_split(returns, min(10, len(returns)//20))
        chunk_returns = [np.mean(chunk) for chunk in chunks]
        chunk_vols = [np.std(chunk) for chunk in chunks]
        ax4.scatter(chunk_vols, chunk_returns, alpha=0.6, s=50)
        ax4.set_xlabel('Volatility')
        ax4.set_ylabel('Return')
        ax4.set_title('Risk-Return Profile')
        ax4.grid(True, alpha=0.3)

    plt.tight_layout()
  ]],
    data_var
  )

  return generate_base_plot_code(data_var, "risk_analysis", config, plot_code)
end

return M