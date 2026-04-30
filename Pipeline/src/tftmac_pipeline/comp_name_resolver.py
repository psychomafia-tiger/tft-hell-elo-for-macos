"""Resolve trait combo signatures to human-readable comp names."""
import json
import re
from pathlib import Path
from typing import Tuple

_MAP_PATH = Path(__file__).parent.parent.parent / "data" / "trait_name_map.json"
_CURATED: dict[str, str] | None = None


def _load_map() -> dict[str, str]:
    global _CURATED
    if _CURATED is None:
        with open(_MAP_PATH) as f:
            raw = json.load(f)
        _CURATED = {k: v for k, v in raw.items() if not k.startswith("_")}
    return _CURATED


def resolve_comp_name(signature: Tuple[Tuple[str, int], ...]) -> str:
    if not signature:
        return "Unknown Comp"
    # Try curated map first — key = sorted trait names joined by '+'
    names_only = sorted(name for name, _ in signature)
    key = "+".join(names_only)
    curated = _load_map()
    if key in curated:
        return curated[key]
    # Fallback: top 2 traits by activation tier
    top2 = sorted(signature, key=lambda x: -x[1])[:2]
    return " ".join(_strip_prefix(name) for name, _ in top2)


_PREFIX_RE = re.compile(r"^(Set|TFT)\d+_")


def _strip_prefix(trait_name: str) -> str:
    """Strip Riot's set prefix (`Set17_`, `TFT17_`, future-proof for `Set18_`, `TFT18_`)."""
    return _PREFIX_RE.sub("", trait_name)
