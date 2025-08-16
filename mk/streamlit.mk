# mk/streamlit.mk
# Optional Streamlit helpers. Works with uv/dev.sh/venv.
APP  ?= app.py
PORT ?= 8501

UV    := $(shell command -v uv 2>/dev/null)
DEVSH := $(shell test -x ./dev.sh && echo yes || echo no)
PYTHON ?= python3
VENV   ?= .venv

.PHONY: app.run

ifdef UV
app.run:
	uv run streamlit run $(APP) --server.port $(PORT)
else
  ifeq ($(DEVSH),yes)
app.run:
	./dev.sh run
  else
app.run:
	$(VENV)/bin/streamlit run $(APP) --server.port $(PORT)
  endif
endif
