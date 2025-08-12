# ------------------------------
# Embedding Playground — Makefile
# Prefers uv; falls back to ./dev.sh; then to venv+pip
# ------------------------------

PYTHON ?= python3
APP    ?= app.py
PORT   ?= 8501
VENV   ?= .venv

# Env detection
UV     := $(shell command -v uv 2>/dev/null)
DEVSH  := $(shell test -x ./dev.sh && echo yes || echo no)

.DEFAULT_GOAL := help

# ------------------------------
# uv path (fastest)
# ------------------------------
ifdef UV

.PHONY: setup install
setup install:
	@if [ ! -f uv.lock ]; then \
	    echo "⚠️  uv.lock not found — creating it for reproducibility..."; \
	    uv sync; \
	else \
	    uv sync; \
	fi
	@if ! git diff --quiet uv.lock 2>/dev/null || ! git diff --cached --quiet uv.lock 2>/dev/null; then \
	    echo "⚠️  uv.lock has changed — remember to commit the updated lockfile."; \
	fi

.PHONY: run
run:
	uv run streamlit run $(APP) --server.port $(PORT)

# Ensure pre-commit + tools are available in the project env
.PHONY: hook-install
hook-install:
	uv run pip install pre-commit black ruff
	uv run pre-commit install

# Run all hooks on the whole repo (useful in CI or before big commits)
.PHONY: fmt
fmt:
	uv run pip install pre-commit black ruff
	uv run pre-commit run --all-files

else  # ===== no uv =====

# ------------------------------
# dev.sh path (installs uv automatically)
# ------------------------------
ifeq ($(DEVSH),yes)

.PHONY: setup install
setup install:
	@if [ ! -f uv.lock ]; then \
	    echo "⚠️  uv.lock not found — will be generated after uv installs..."; \
	fi
	./dev.sh uv sync
	@if ! git diff --quiet uv.lock 2>/dev/null || ! git diff --cached --quiet uv.lock 2>/dev/null; then \
	    echo "⚠️  uv.lock has changed — remember to commit the updated lockfile."; \
	fi

.PHONY: run
run:
	./dev.sh run

.PHONY: hook-install
hook-install:
	./dev.sh uv run pip install pre-commit black ruff
	./dev.sh uv run pre-commit install

.PHONY: fmt
fmt:
	./dev.sh uv run pip install pre-commit black ruff
	./dev.sh uv run pre-commit run --all-files

else  # ===== classic venv+pip fallback =====

# ------------------------------
# classic venv+pip fallback
# ------------------------------
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
	# Basic fallback for pyproject users without uv/poetry; installs project in editable mode
	$(VENV)/bin/pip install -e .
else
	@echo "No requirements.txt or pyproject.toml found."; exit 1
endif

.PHONY: run
run:
	$(VENV)/bin/streamlit run $(APP) --server.port $(PORT)

.PHONY: hook-install
hook-install:
	$(VENV)/bin/pip install pre-commit black ruff
	$(VENV)/bin/pre-commit install

.PHONY: fmt
fmt:
	$(VENV)/bin/pip install pre-commit black ruff
	$(VENV)/bin/pre-commit run --all-files

endif  # DEVSH
endif  # UV

# ------------------------------
# Shared targets
# ------------------------------
.PHONY: clean
clean:
	rm -rf $(VENV) __pycache__ .pytest_cache .ruff_cache .streamlit/**/__pycache__

.PHONY: check
check:
	@echo "Running formatters and linters…"
	$(MAKE) fmt

.PHONY: help
help:
	@echo "Targets:"
	@echo "  make install       - Install deps (uv/dev.sh/venv fallback)"
	@echo "  make run           - Run the Streamlit app on port $(PORT)"
	@echo "  make hook-install  - Install pre-commit hooks in this repo"
	@echo "  make fmt           - Run all pre-commit hooks on all files"
	@echo "  make clean         - Remove venv and caches"
	@echo "  make check         - Alias for fmt"
