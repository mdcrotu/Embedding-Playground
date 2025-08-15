# ------------------------------
# Embedding Playground — Makefile (cleaned)
# Prefers uv/uvx; falls back to ./dev.sh; then to venv+pip
# ------------------------------

PYTHON ?= python3
APP    ?= app.py
PORT   ?= 8501
VENV   ?= .venv

# Env detection
UV     := $(shell command -v uv 2>/dev/null)
DEVSH  := $(shell test -x ./dev.sh && echo yes || echo no)

.DEFAULT_GOAL := help

# ==============================
# Path A: uv available
# ==============================
ifdef UV

.PHONY: setup install
setup install:
	@echo "🔧 syncing via uv..."
	@uv sync
	@if ! git diff --quiet uv.lock 2>/dev/null || ! git diff --cached --quiet uv.lock 2>/dev/null; then \
	    echo "⚠️  uv.lock changed — commit the updated lockfile."; \
	fi

.PHONY: run
run:
	uv run streamlit run $(APP) --server.port $(PORT)

# ---- pre-commit integration (managed envs) ----
.PHONY: hooks hooks-update hooks-uninstall pre-commit fmt format lint
hooks:
	uvx pre-commit install --install-hooks

hooks-update:
	uvx pre-commit autoupdate

hooks-uninstall:
	uvx pre-commit uninstall || true
	uvx pre-commit uninstall -t commit-msg || true

# Run all hooks on the whole repo (useful locally & in CI)
pre-commit fmt:
	uvx pre-commit run --all-files

# One-off formatting outside of pre-commit (optional)
format:
	uvx black .
	uvx ruff format .

# Lint-only (no fixes)
lint:
	uvx ruff check .

# Convenience: format + run hooks
.PHONY: format-all
format-all: format pre-commit

else  # ===== Path B: uv not available =====

# ==============================
# Path B1: dev.sh available (bootstraps uv internally)
# ==============================
ifeq ($(DEVSH),yes)

.PHONY: setup install
setup install:
	@echo "🔧 syncing via dev.sh (uv)..."
	./dev.sh uv sync
	@if ! git diff --quiet uv.lock 2>/dev/null || ! git diff --cached --quiet uv.lock 2>/dev/null; then \
	    echo "⚠️  uv.lock changed — commit the updated lockfile."; \
	fi

.PHONY: run
run:
	./dev.sh run

# pre-commit is managed by pre-commit itself; no need to install black/ruff here
.PHONY: hooks hooks-update hooks-uninstall pre-commit fmt format lint
hooks:
	./dev.sh uv run pre-commit install --install-hooks

hooks-update:
	./dev.sh uv run pre-commit autoupdate

hooks-uninstall:
	./dev.sh uv run pre-commit uninstall || true
	./dev.sh uv run pre-commit uninstall -t commit-msg || true

pre-commit fmt:
	./dev.sh uv run pre-commit run --all-files

format:
	./dev.sh uvx black .
	./dev.sh uvx ruff format .

lint:
	./dev.sh uvx ruff check .

.PHONY: format-all
format-all: format pre-commit

# ==============================
# Path B2: classic venv+pip fallback
# ==============================
else

$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/$(PYTHON) -m pip install --upgrade pip

.PHONY: setup
setup: $(VENV)/bin/activate

.PHONY: install
install: setup
ifneq ("$(wildcard requirements.txt)","")
	$(VENV)/bin/pip install -r requirements.txt
else ifneq ("$(wildcard pyproject.toml)","")
	# Basic fallback install; pre-commit will still manage hook tool envs
	$(VENV)/bin/pip install -e .
else
	@echo "No requirements.txt or pyproject.toml found."; exit 1
endif

.PHONY: run
run:
	$(VENV)/bin/streamlit run $(APP) --server.port $(PORT)

.PHONY: hooks hooks-update hooks-uninstall pre-commit fmt format lint
hooks:
	$(VENV)/bin/pip install pre-commit
	$(VENV)/bin/pre-commit install --install-hooks

hooks-update:
	$(VENV)/bin/pre-commit autoupdate

hooks-uninstall:
	$(VENV)/bin/pre-commit uninstall || true
	$(VENV)/bin/pre-commit uninstall -t commit-msg || true

pre-commit fmt:
	$(VENV)/bin/pre-commit run --all-files

# Optional direct formatters (not required for commits)
format:
	$(VENV)/bin/pip install black ruff
	$(VENV)/bin/black .
	$(VENV)/bin/ruff format .

lint:
	$(VENV)/bin/pip install ruff
	$(VENV)/bin/ruff check .

.PHONY: format-all
format-all: format pre-commit

endif  # DEVSH
endif  # UV

# ==============================
# Shared targets
# ==============================
.PHONY: clean
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache .ruff_cache .streamlit/**/__pycache__

.PHONY: check
check:
	@echo "Running all hooks…"
	$(MAKE) fmt

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make install       - Install deps (uv/dev.sh/venv fallback)"
	@echo "  make run           - Run the Streamlit app on port $(PORT)"
	@echo "  make hooks         - Install pre-commit hooks (incl. commit-msg)"
	@echo "  make fmt           - Run all pre-commit hooks on all files"
	@echo "  make format        - One-off Black + Ruff format (optional)"
	@echo "  make lint          - Ruff check only"
	@echo "  make format-all    - format + run hooks"
	@echo "  make clean         - Remove venv and caches"
	@echo "  make check         - Alias for fmt"
