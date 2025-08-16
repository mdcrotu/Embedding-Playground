# mk/ai-commit.mk
# Reusable AI commit hook targets. Works in any repo.

# Public targets:
# - hook-ollama / hook-openai / hook-anthropic / hook-show
# - hooks / hooks-update / hooks-uninstall
# - fmt (run all hooks on all files)

.PHONY: hooks hooks-update hooks-uninstall hook-ollama hook-openai hook-anthropic hook-show fmt

# Install pre-commit hooks (includes prepare-commit-msg stage)
hooks: .ensure-precommit
	$(PRECOMMIT_CMD) install --install-hooks

hooks-update:
	$(PRECOMMIT_CMD) autoupdate

hooks-uninstall:
	$(PRECOMMIT_CMD) uninstall || true
	$(PRECOMMIT_CMD) uninstall -t prepare-commit-msg || true

# Backend switchers write .env.ai and reinstall the prepare-commit-msg hook
hook-ollama: .ensure-precommit
	@printf "AI_BACKEND=ollama\nOLLAMA_MODEL=%s\n" "llama3:8b" > .env.ai
	@echo "Set backend to Ollama (llama3:8b) in .env.ai"
	$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

hook-openai: .ensure-precommit
	@if [ -z "$$OPENAI_API_KEY" ]; then echo "OPENAI_API_KEY not set in env"; exit 1; fi
	@printf "AI_BACKEND=openai\nOPENAI_MODEL=%s\n" "gpt-4o-mini" > .env.ai
	@echo "Set backend to OpenAI (gpt-4o-mini) in .env.ai"
	$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

hook-anthropic: .ensure-precommit
	@if [ -z "$$ANTHROPIC_API_KEY" ]; then echo "ANTHROPIC_API_KEY not set in env"; exit 1; fi
	@printf "AI_BACKEND=anthropic\nANTHROPIC_MODEL=%s\n" "claude-sonnet-4-20250514" > .env.ai
	@echo "Set backend to Anthropic (claude-sonnet-4-20250514) in .env.ai"
	$(PRECOMMIT_CMD) install --hook-type prepare-commit-msg --install-hooks

hook-show:
	@echo "---- .env.ai ----"
	@([ -f .env.ai ] && cat .env.ai) || echo "(no .env.ai; defaulting to AI_BACKEND=ollama)"

# Run all hooks on the whole repo (useful locally & in CI)
fmt:
	$(PRECOMMIT_CMD) run --all-files
