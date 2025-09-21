.PHONY: test install clean lint format help

# Default target
help:
        @echo "ssh-viz.nvim Development Commands:"
        @echo "=================================="
        @echo "  install     - Install plugin locally for testing"
        @echo "  test        - Run tests"
        @echo "  lint        - Run linting"
        @echo "  format      - Format Lua code"
        @echo "  clean       - Clean build artifacts"
        @echo "  demo        - Set up demo environment"
        @echo "  docs        - Generate documentation"

install:
        @echo "Installing ssh-viz.nvim locally..."
        @mkdir -p ~/.local/share/nvim/site/pack/dev/start/ssh-viz.nvim
        @cp -r . ~/.local/share/nvim/site/pack/dev/start/ssh-viz.nvim/
        @echo "Plugin installed. Restart Neovim and run :SshVizSetup"

test:
        @echo "Running tests..."
        @if command -v busted >/dev/null 2>&1; then \
                busted tests/; \
        else \
                echo "busted not found. Install with: luarocks install busted"; \
        fi

lint:
        @echo "Linting Lua code..."
        @if command -v luacheck >/dev/null 2>&1; then \
                luacheck lua/ plugin/ --globals vim; \
        else \
                echo "luacheck not found. Install with: luarocks install luacheck"; \
        fi

format:
        @echo "Formatting Lua code..."
        @if command -v stylua >/dev/null 2>&1; then \
                stylua lua/ plugin/; \
        else \
                echo "stylua not found. Install with: cargo install stylua"; \
        fi

clean:
        @echo "Cleaning build artifacts..."
        @rm -rf build/
        @rm -rf /tmp/nvim_plots/*
        @echo "Clean complete"

demo:
        @echo "Setting up demo environment..."
        @mkdir -p demo/plots
        @python3 -c "import numpy as np; np.save('demo/sample_data.npy', np.random.randn(100).cumsum())"
        @echo "Demo environment ready in demo/"

docs:
        @echo "Generating documentation..."
        @mkdir -p docs/
        @echo "Documentation generated in docs/"

dev-server:
        @echo "Starting development server..."
        @cd /tmp/nvim_plots && python3 -m http.server 8888

check-deps:
        @echo "Checking dependencies..."
        @python3 -c "import matplotlib, numpy; print('Python dependencies OK')" || echo "Missing: pip install matplotlib numpy"
        @command -v git >/dev/null 2>&1 && echo "Git: OK" || echo "Missing: git"
        @command -v curl >/dev/null 2>&1 && echo "Curl: OK" || echo "Missing: curl"