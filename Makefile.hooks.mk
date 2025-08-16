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

.PHONY: check
check:
	@echo "Running all hooks…"
	$(MAKE) fmt
