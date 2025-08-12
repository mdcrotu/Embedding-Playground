#!/usr/bin/env bash
set -e

# Where uv gets installed by default (user-local bin dir)
UV_BIN="$HOME/.local/bin/uv"

# Function to install uv if missing
install_uv() {
    echo "⚙️ Installing uv package manager..."
    if command -v curl >/dev/null 2>&1; then
        curl -LsSf https://astral.sh/uv/install.sh | sh
    elif command -v wget >/dev/null 2>&1; then
        wget -qO- https://astral.sh/uv/install.sh | sh
    else
        echo "❌ Need curl or wget to install uv"
        exit 1
    fi
}

# Ensure uv is installed
if ! command -v uv >/dev/null 2>&1; then
    install_uv
    # Add to PATH for this session
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v uv >/dev/null 2>&1; then
        echo "❌ uv not found in PATH after install."
        echo "   You may need to add $HOME/.local/bin to your PATH."
        exit 1
    fi
fi

# First-time sync (if .venv not present)
if [ ! -d ".venv" ]; then
    echo "📦 Setting up project environment..."
    if [ -f "pyproject.toml" ]; then
        uv sync
    elif [ -f "requirements.txt" ]; then
        uv pip install -r requirements.txt
    else
        echo "⚠️ No pyproject.toml or requirements.txt found."
    fi
fi

# If no args, just give a help message
if [ $# -eq 0 ]; then
    echo "Usage: ./dev.sh <command>"
    echo
    echo "Examples:"
    echo "  ./dev.sh run           # Run the Streamlit app"
    echo "  ./dev.sh fmt           # Format with black + ruff"
    echo "  ./dev.sh uv sync       # Manually sync deps"
    exit 0
fi

# Common shortcuts
case "$1" in
    run)
        shift
        uv run streamlit run app.py --server.port 8501 "$@"
        ;;
    fmt)
        shift
        uv run pip install black ruff
        uv run black .
        uv run ruff check --fix .
        ;;
    *)
        # Pass anything else directly to uv
        uv "$@"
        ;;
esac
