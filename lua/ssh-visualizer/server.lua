-- lua/ssh-viz/server.lua
-- Web server functionality for ssh-viz plugin

local utils = require("ssh-viz.utils")
local M = {}

-- Generate Python code for HTTP server
function M.generate_server_code(config)
  local output_dir = utils.get_output_dir(config)
  local host = config.web_server.host
  local port = config.web_server.port
  local cors_enabled = config.web_server.cors_enabled and "True" or "False"

  return string.format(
    [[
# ssh-viz plot server
import http.server
import socketserver
import os
import threading
import json
import urllib.parse
from datetime import datetime

class PlotHTTPHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory='%s', **kwargs)

    def end_headers(self):
        # Disable caching for live updates
        self.send_header('Cache-Control', 'no-cache, no-store, must-revalidate')
        self.send_header('Pragma', 'no-cache')
        self.send_header('Expires', '0')

        # Enable CORS if configured
        if %s:
            self.send_header('Access-Control-Allow-Origin', '*')
            self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
            self.send_header('Access-Control-Allow-Headers', 'Content-Type')

        super().end_headers()

    def do_GET(self):
        if self.path == '/':
            self.send_directory_listing()
        elif self.path == '/api/plots':
            self.send_plot_list()
        elif self.path == '/api/status':
            self.send_status()
        else:
            super().do_GET()

    def send_directory_listing(self):
        """Custom directory listing with plot previews"""
        self.send_response(200)
        self.send_header('Content-type', 'text/html; charset=utf-8')
        self.end_headers()

        html = '''
        <!DOCTYPE html>
        <html>
        <head>
            <title>ssh-viz Plot Server</title>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                body { font-family: system-ui, sans-serif; margin: 20px; background: #f8f9fa; }
                .container { max-width: 1200px; margin: 0 auto; }
                .header { background: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
                .plot-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
                .plot-card { background: white; border-radius: 8px; padding: 15px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
                .plot-card img { max-width: 100%%; height: auto; border-radius: 4px; }
                .plot-info { margin-top: 10px; font-size: 0.9em; color: #666; }
                .refresh-btn { background: #007bff; color: white; border: none; padding: 10px 20px; border-radius: 4px; cursor: pointer; }
                .refresh-btn:hover { background: #0056b3; }
                .status { background: #d4edda; padding: 10px; border-radius: 4px; margin-bottom: 20px; }
            </style>
            <script>
                function refreshPage() { location.reload(); }
                // Auto-refresh every 30 seconds
                setInterval(refreshPage, 30000);

                async function loadPlots() {
                    try {
                        const response = await fetch('/api/plots');
                        const plots = await response.json();
                        const grid = document.getElementById('plot-grid');

                        grid.innerHTML = plots.map(plot => `
                            <div class="plot-card">
                                <h3>${plot.name}</h3>
                                <a href="${plot.html}" target="_blank">
                                    <img src="${plot.image}" alt="${plot.name}" onerror="this.style.display='none'">
                                </a>
                                <div class="plot-info">
                                    <div>Modified: ${plot.modified}</div>
                                    <div>Size: ${plot.size}</div>
                                </div>
                            </div>
                        `).join('');
                    } catch (e) {
                        console.error('Failed to load plots:', e);
                    }
                }

                window.onload = loadPlots;
            </script>
        </head>
        <body>
            <div class="container">
                <div class="header">
                    <h1>ssh-viz Plot Server</h1>
                    <div class="status">
                        Server running on port %d | Auto-refresh: 30s
                        <button class="refresh-btn" onclick="refreshPage()">Refresh Now</button>
                    </div>
                </div>
                <div id="plot-grid" class="plot-grid">
                    Loading plots...
                </div>
            </div>
        </body>
        </html>
        '''

        self.wfile.write(html.encode('utf-8'))

    def send_plot_list(self):
        """API endpoint for plot metadata"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

        plots = []
        try:
            for filename in os.listdir('.'):
                if filename.endswith(('.png', '.html')):
                    stat = os.stat(filename)
                    plots.append({
                        'name': filename,
                        'html': filename if filename.endswith('.html') else filename.replace('.png', '.html'),
                        'image': filename if filename.endswith('.png') else filename.replace('.html', '.png'),
                        'modified': datetime.fromtimestamp(stat.st_mtime).strftime('%%Y-%%m-%%d %%H:%%M'),
                        'size': f"{stat.st_size // 1024}KB" if stat.st_size > 1024 else f"{stat.st_size}B"
                    })
        except Exception as e:
            print(f"Error listing plots: {e}")

        self.wfile.write(json.dumps(plots).encode('utf-8'))

    def send_status(self):
        """API endpoint for server status"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.end_headers()

        status = {
            'status': 'running',
            'timestamp': datetime.now().isoformat(),
            'port': %d,
            'directory': os.getcwd(),
            'plot_count': len([f for f in os.listdir('.') if f.endswith(('.png', '.html'))])
        }

        self.wfile.write(json.dumps(status).encode('utf-8'))

    def log_message(self, format, *args):
        """Custom logging"""
        print(f"[{datetime.now().strftime('%%H:%%M:%%S')}] {format %% args}")

class ThreadedHTTPServer(socketserver.ThreadingMixIn, socketserver.TCPServer):
    """Handle requests in separate threads"""
    allow_reuse_address = True
    daemon_threads = True

def start_plot_server():
    """Start the plot server"""
    try:
        os.chdir('%s')
        print(f"Starting plot server in directory: {os.getcwd()}")

        with ThreadedHTTPServer(('%s', %d), PlotHTTPHandler) as httpd:
            print(f"✓ Plot server running at http://%s:%d")
            print(f"✓ Access plots via your browser")
            print(f"✓ API endpoints: /api/plots, /api/status")
            print("✓ Press Ctrl+C to stop server")

            try:
                httpd.serve_forever()
            except KeyboardInterrupt:
                print("\\n✓ Server stopped")

    except OSError as e:
        if e.errno == 98:  # Address already in use
            print(f"✗ Port %d is already in use")
            print("Try a different port or stop the existing server")
        else:
            print(f"✗ Server error: {e}")
    except Exception as e:
        print(f"✗ Unexpected server error: {e}")

# Start server in background thread
import atexit

def cleanup_server():
    print("Cleaning up plot server...")

atexit.register(cleanup_server)

# Start the server
server_thread = threading.Thread(target=start_plot_server, daemon=True)
server_thread.start()

print("ssh-viz plot server started in background")
print("Use Ctrl+C in the REPL to stop the server")
]],
    output_dir,
    cors_enabled,
    port,
    port,
    port,
    output_dir,
    host,
    port,
    host,
    port,
    port
  )
end

-- Generate simple file server (lightweight alternative)
function M.generate_simple_server_code(config)
  local output_dir = utils.get_output_dir(config)
  local port = config.web_server.port

  return string.format(
    [[
# Simple plot file server
import http.server
import socketserver
import os
import threading
from pathlib import Path

def serve_plots():
    os.chdir('%s')
    handler = http.server.SimpleHTTPRequestHandler

    class CustomHandler(handler):
        def end_headers(self):
            self.send_header('Cache-Control', 'no-cache')
            super().end_headers()

    with socketserver.TCPServer(("", %d), CustomHandler) as httpd:
        print(f"Simple plot server: http://localhost:%d")
        httpd.serve_forever()

# Start in background
threading.Thread(target=serve_plots, daemon=True).start()
print("Plot server started (simple mode)")
]],
    output_dir,
    port,
    port
  )
end

-- Check if server is accessible
function M.check_server_status(config)
  local check_code = string.format(
    [[
import urllib.request
import json

try:
    with urllib.request.urlopen('http://localhost:%d/api/status', timeout=5) as response:
        data = json.loads(response.read().decode())
        print(f"✓ Server is running - {data['plot_count']} plots available")
        print(f"✓ Directory: {data['directory']}")
except Exception as e:
    print(f"✗ Server not accessible: {e}")
    print("Start server with: require('ssh-viz').start_server()")
]],
    config.web_server.port
  )

  return check_code
end

-- Generate server monitoring code
function M.generate_monitor_code(config)
  return string.format(
    [[
# ssh-viz server monitor
import time
import requests
import json
from datetime import datetime

def monitor_server():
    url = 'http://localhost:%d/api/status'

    while True:
        try:
            response = requests.get(url, timeout=5)
            data = response.json()

            print(f"[{datetime.now().strftime('%%H:%%M:%%S')}] "
                  f"Server OK - {data['plot_count']} plots")

        except Exception as e:
            print(f"[{datetime.now().strftime('%%H:%%M:%%S')}] "
                  f"Server error: {e}")

        time.sleep(30)  # Check every 30 seconds

# Start monitoring in background
import threading
monitor_thread = threading.Thread(target=monitor_server, daemon=True)
monitor_thread.start()
print("Server monitoring started")
]],
    config.web_server.port
  )
end

return M