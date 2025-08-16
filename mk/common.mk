# mk/common.mk
# Common detection + shared vars. Language agnostic.

# Defaults you can override from the project Makefile or CLI
PYTHON ?= python3
VENV   ?= .venv

# Env detection
UV    := $(shell command -v uv 2>/dev/null)
DEVSH := $(shell test -x ./dev.sh && echo yes || echo no)

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

# Ensure pre-commit exists where needed (no-op on uv/dev.sh)
.PHONY: .ensure-precommit
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
