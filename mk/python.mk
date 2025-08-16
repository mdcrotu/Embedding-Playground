# mk/python.mk
# Python environment helpers (uv/dev.sh/venv fallback).
# Targets are namespaced as py.* to avoid collisions.

PYTHON ?= python3
VENV   ?= .venv

# Detect once again (in case this file used alone)
UV    := $(shell command -v uv 2>/dev/null)
DEVSH := $(shell test -x ./dev.sh && echo yes || echo no)

.PHONY: py.setup py.install py.clean

# py.setup: create env (sync if uv; else ensure venv)
ifdef UV
py.setup:
	@echo "🔧 syncing via uv..."
	uv sync
else
  ifeq ($(DEVSH),yes)
py.setup:
	@echo "🔧 syncing via dev.sh (uv)..."
	./dev.sh uv sync
  else
py.setup: $(VENV)/bin/activate
$(VENV)/bin/activate:
	$(PYTHON) -m venv $(VENV)
	$(VENV)/bin/$(PYTHON) -m pip install --upgrade pip
  endif
endif

# py.install: install project (venv path only; uv users get it in py.setup)
ifdef UV
py.install: py.setup
	@true
else
  ifeq ($(DEVSH),yes)
py.install: py.setup
	@true
  else
py.install: py.setup
ifneq ("$(wildcard requirements.txt)","")
	$(VENV)/bin/pip install -r requirements.txt
else ifneq ("$(wildcard pyproject.toml)","")
	$(VENV)/bin/pip install -e .
else
	@echo "No requirements.txt or pyproject.toml found."; exit 1
endif
  endif
endif

py.clean:
	rm -rf $(VENV) __pycache__ .pytest_cache .ruff_cache
