# TFT Hell Elo — Pipeline Makefile
#
# Targets:
#   make pipeline-test   — run all pytest tests (fixture-based, no live API)
#   make smoke           — ONLY way to hit live Riot API (manual local dev)
#   make install         — install package in editable mode with dev deps
#   make typecheck       — run mypy on pipeline package

PYTHON := .venv/bin/python
PIP    := .venv/bin/pip
PYTEST := .venv/bin/pytest

# Default output for smoke test
SMOKE_OUTPUT ?= /tmp/tft-tier-list-smoke.json
SMOKE_REGION ?= vn2
SMOKE_MAX    ?= 100

.PHONY: install pipeline-test smoke typecheck clean

## install: create venv (if needed) + install package + dev deps
install:
	@if [ ! -d .venv ]; then python3 -m venv .venv; fi
	$(PIP) install -e ".[dev]" --quiet

## pipeline-test: run pytest against fixtures — zero live API calls
pipeline-test:
	$(PYTEST) tests/ -v --tb=short

## smoke: hit live Riot API (requires RIOT_API_KEY env var set)
## Usage: RIOT_API_KEY=RGAPI-xxx make smoke
smoke:
	@if [ -z "$$RIOT_API_KEY" ]; then \
		echo "ERROR: RIOT_API_KEY not set. Export it first:"; \
		echo "  export RIOT_API_KEY=RGAPI-..."; \
		exit 1; \
	fi
	$(PYTHON) -m tftmac_pipeline.run_aggregator \
		--region $(SMOKE_REGION) \
		--max-matches $(SMOKE_MAX) \
		--output $(SMOKE_OUTPUT)
	@echo ""
	@echo "Smoke output → $(SMOKE_OUTPUT)"
	@$(PYTHON) -c "import json,sys; d=json.load(open('$(SMOKE_OUTPUT)')); \
		print(f'schema_version: {d[\"schema_version\"]}'); \
		print(f'region: {d[\"region\"]}'); \
		print(f'total_matches_sampled: {d[\"total_matches_sampled\"]}'); \
		print(f'comps: {len(d[\"comps\"])}'); \
		[print(f'  {c[\"tier\"]} {c[\"name\"]} play_rate={c[\"play_rate\"]:.3f} avg_place={c[\"avg_placement\"]:.2f}') for c in d['comps'][:10]]"

## typecheck: run mypy on the pipeline package source
typecheck:
	@if command -v .venv/bin/mypy > /dev/null 2>&1; then \
		.venv/bin/mypy src/tftmac_pipeline/ --ignore-missing-imports; \
	else \
		echo "mypy not installed — run: $(PIP) install mypy"; \
	fi

## clean: remove build artifacts
clean:
	rm -rf src/tftmac_pipeline.egg-info dist build __pycache__
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
