"""Thin script shim — forwards to installable package entrypoint.

Usage (from repo root):
  cd Pipeline && .venv/bin/python scripts/run_aggregator.py --region vn2 --output data/tier-list.json

Preferred invocation after `pip install -e .`:
  tft-aggregate --region vn2 --output data/tier-list.json
  python -m tftmac_pipeline.run_aggregator --region vn2

This shim exists for convenience when running from the scripts/ directory
without installing the package. All logic lives in:
  src/tftmac_pipeline/run_aggregator.py
"""
from tftmac_pipeline.run_aggregator import main_sync

if __name__ == "__main__":
    main_sync()
