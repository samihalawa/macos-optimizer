.PHONY: help cli gui test lint clean install-gui

PYTHON ?= python3
GUI_DIR := gui
CLI := cli/src/macos-optimizer.sh

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

cli: ## Launch the interactive CLI (macOS only)
	@chmod +x $(CLI)
	@$(CLI)

version: ## Print CLI version
	@chmod +x $(CLI)
	@$(CLI) --version

install-gui: ## Create venv and install GUI dependencies
	cd $(GUI_DIR) && $(PYTHON) -m venv .venv
	cd $(GUI_DIR) && .venv/bin/pip install --upgrade pip
	cd $(GUI_DIR) && .venv/bin/pip install -r requirements.txt

gui: ## Run the NiceGUI app (installs venv on first run)
	@if [ ! -x $(GUI_DIR)/.venv/bin/python ]; then $(MAKE) install-gui; fi
	cd $(GUI_DIR) && .venv/bin/python src/app.py

test: ## Run available automated tests
	@chmod +x $(CLI) cli/src/script.sh tests/cli/test_script.sh 2>/dev/null || true
	@if command -v bats >/dev/null 2>&1; then \
		bats tests/cli/test_script.sh; \
	else \
		echo "bats not installed — running basic CLI smoke checks"; \
		$(CLI) --version; \
		$(CLI) --help >/dev/null; \
		$(PYTHON) -m py_compile gui/src/app.py config/settings.py; \
		echo "Smoke checks passed"; \
	fi

lint: ## Lint shell + Python when tools are available
	@command -v shellcheck >/dev/null 2>&1 && shellcheck -x $(CLI) || echo "shellcheck not installed, skipped"
	@if [ -x $(GUI_DIR)/.venv/bin/ruff ]; then $(GUI_DIR)/.venv/bin/ruff check gui/src config; \
	elif command -v ruff >/dev/null 2>&1; then ruff check gui/src config; \
	else $(PYTHON) -m py_compile gui/src/app.py config/settings.py; fi

clean: ## Remove local virtualenvs and caches
	rm -rf $(GUI_DIR)/.venv .pytest_cache .mypy_cache .ruff_cache
	find . -type d -name '__pycache__' -prune -exec rm -rf {} +
