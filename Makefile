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

# Unified pre-commit runner per environment
ifeq ($(strip $(UV)),)
  ifeq ($(DEVSH),yes)
    PRECOMMIT_CMD := ./dev.sh uv run pre-commit
  else
    PRECOMMIT_CMD := $(VENV)/bin/pre-commit
  endif
else
  PRECOMMIT_CMD := uvx pre-commit
endif


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
	uvx pre-commit uninstall -t prepare-commit-msg || true

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
	./dev.sh uv run pre-commit uninstall -t prepare-commit-msg || true

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
	$(VENV)/bin/pre-commit uninstall -t prepare-commit-msg || true

# Show current backend settings
hook-show:
	@echo "---- .env.ai ----"
	@([ -f .env.ai ] && cat .env.ai) || echo "(no .env.ai; defaulting to AI_BACKEND=ollama)"

# Run all hooks on the whole repo (useful locally & in CI)
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
.PHONY: hook-ollama hook-openai hook-anthropic hook-show .ensure-precommit

# Ensure pre-commit exists where needed (no-op on uv/dev.sh)
.ensure-precommit:
ifeq ($(strip $(UV)),)
  ifneq ($(DEVSH),yes)
	@mkdir -p $(VENV)
	@([ -x "$(VENV)/bin/pre-commit" ] || { \
	  echo "Installing pre-commit into $(VENV) …"; \
	  $(PYTHON) -m venv $(VENV); \
	  $(VENV)/bin/pip install --upgrade pip pre-commit; \
	})
  endif
endif
	@true

# Set backend to Ollama (local)
hook-ollama: .ensure-precommit
	@printf "AI_BACKEND=ollama\nOLLAMA_MODEL=%s\n" "llama3:8b" > .env.ai
	@echo "Set backend to Ollama (llama3:8b) in .env.ai"
	@$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

# Set backend to OpenAI (cloud)
hook-openai: .ensure-precommit
	@if [ -z "$$OPENAI_API_KEY" ]; then echo "OPENAI_API_KEY not set in env"; exit 1; fi
	@printf "AI_BACKEND=openai\nOPENAI_MODEL=%s\n" "gpt-4o-mini" > .env.ai
	@echo "Set backend to OpenAI (gpt-4o-mini) in .env.ai"
	@$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

# Set backend to Anthropic (cloud)
hook-anthropic: .ensure-precommit
	@if [ -z "$$ANTHROPIC_API_KEY" ]; then echo "ANTHROPIC_API_KEY not set in env"; exit 1; fi
	@printf "AI_BACKEND=anthropic\nANTHROPIC_MODEL=%s\n" "claude-sonnet-4-20250514" > .env.ai
	@echo "Set backend to Anthropic (claude-sonnet-4-20250514) in .env.ai"
	@$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

# Show current backend settings
hook-show:
	@echo "---- .env.ai ----"
	@([ -f .env.ai ] && cat .env.ai) || echo "(no .env.ai; defaulting to AI_BACKEND=ollama)"

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
	@echo "  ----------------"
	@echo "  make install       - Install deps (uv/dev.sh/venv fallback)"
	@echo "  make run           - Run the Streamlit app on port $(PORT)"
	@echo "  ----------------"
	@echo "  make hook-ollama   - Use local Ollama for AI commit messages"
	@echo "  make hook-openai   - Use OpenAI (requires OPENAI_API_KEY)"
	@echo "  make hook-anthropic- Use Anthropic (requires ANTHROPIC_API_KEY)"
	@echo "  make hook-show     - Show current AI backend settings"
	@echo "  make hooks         - Install pre-commit hooks (incl. prepare-commit-msg)"
	@echo "  ----------------"
	@echo "  make fmt           - Run all pre-commit hooks on all files"
	@echo "  make format        - One-off Black + Ruff format (optional)"
	@echo "  make lint          - Ruff check only"
	@echo "  make format-all    - format + run hooks"
	@echo "  make clean         - Remove venv and caches"
	@echo "  make check         - Alias for fmt"
