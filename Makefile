# Makefile (tiny, project-specific)
# Include only what you need
include mk/common.mk
include mk/ai-commit.mk
include mk/python.mk
include mk/streamlit.mk   # optional; remove if not a Streamlit app

.DEFAULT_GOAL := help

.PHONY: install run clean help

install: py.install
run:     app.run

clean: py.clean
	rm -rf .streamlit/**/__pycache__

help:
	@echo "Targets:"
	@echo "  install           - Python install (uv/dev.sh/venv fallback)"
	@echo "  run               - Run Streamlit app (if included)"
	@echo "  hooks             - Install pre-commit hooks"
	@echo "  hooks-update      - Update pre-commit hook versions"
	@echo "  hooks-uninstall   - Remove pre-commit hooks"
	@echo "  hook-ollama       - Use local Ollama for AI commit messages"
	@echo "  hook-openai       - Use OpenAI for AI commit messages"
	@echo "  hook-anthropic    - Use Anthropic for AI commit messages"
	@echo "  hook-show         - Show current AI backend settings"
	@echo "  fmt               - Run all pre-commit hooks on all files"
	@echo "  clean             - Remove venv/caches"
