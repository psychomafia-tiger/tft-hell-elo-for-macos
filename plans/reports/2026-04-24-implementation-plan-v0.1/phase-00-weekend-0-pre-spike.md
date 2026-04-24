# Phase 0 — Weekend 0 Pre-spike Assignment (48h)

**Status**: in_progress
**Duration**: 2 days (2026-04-24 → 2026-04-26)
**Blocker for**: Phase 1 Weekend 1 code start
**Gate**: All 6 action items COMPLETED

## Context Links

- Input spec: `docs/product-spec-v0.1.md`
- Eng review: `plans/reports/2026-04-24-eng-review-v0.1.md` §Weekend 0 Assignment
- CLAUDE.md rules: Communication Language + Plain-language Explanation

## Overview

Weekend 0 Assignment từ eng review có 6 action items. Phân 2 loại (split 2 categories):

- **AI-executable (TDD-fit ngay)**: #2 install.sh, #4 comp detection algorithm foundation
- **Founder-manual (tracked, not TDD-able)**: #1 Production key apply, #3 API data verify, #5 P2 overlay test, #6 wireframe

**Ví dụ concrete lý do split**: #3 (Riot API data structure verify) cần Dev key thật + 20-30 matches fetch. AI không có credentials → founder làm manual 2h. Ngược lại, #4 Jaccard algorithm = pure function (hàm thuần, input→output deterministic), full TDD cycle chạy offline với fixtures (dữ liệu giả).

---

## File Structure (create)

```
Pipeline/                                  # Python pipeline code
├── pyproject.toml                         # Poetry/uv project config
├── src/
│   └── tftmac_pipeline/
│       ├── __init__.py
│       ├── comp_signature.py              # Signature string generation
│       ├── jaccard.py                     # Jaccard similarity function
│       ├── comp_grouping.py               # Group similar signatures
│       ├── tier_calculator.py             # Tier formula (S/A/B/C)
│       ├── carry_detector.py              # Carry heuristic + override
│       └── augment_aggregator.py          # Top-3 augments per comp
├── tests/
│   ├── conftest.py                        # Pytest fixtures
│   ├── fixtures/
│   │   ├── sample_matches.json            # 5 hand-crafted matches for tests
│   │   └── hand_labeled_groups.json       # 10 groups for threshold tuning
│   ├── test_jaccard.py
│   ├── test_comp_signature.py
│   ├── test_comp_grouping.py
│   ├── test_tier_calculator.py
│   ├── test_carry_detector.py
│   └── test_augment_aggregator.py
└── scripts/
    └── tune_jaccard_threshold.py          # Pre-spike action #4 tuning script

Distribution/                              # Distribution assets
├── install.sh                             # One-command onboarding
└── tests/
    └── test_install.bats                  # bats-core shell tests

docs/
└── pre-spike-algo-tuning.md               # Action #4 output artifact (founder fills Day 2)
```

---

## Task 0.1: Set up Pipeline Python project

**Files:**
- Create: `Pipeline/pyproject.toml`
- Create: `Pipeline/src/tftmac_pipeline/__init__.py`
- Create: `Pipeline/tests/conftest.py`
- Create: `Pipeline/.gitignore`

- [ ] **Step 1: Create pyproject.toml** (bật uv hoặc pip, tối thiểu Python 3.11+)

```toml
[project]
name = "tftmac-pipeline"
version = "0.1.0"
requires-python = ">=3.11"
dependencies = [
  "aiohttp>=3.9",
  "aiolimiter>=1.1",
  "boto3>=1.34",
]

[project.optional-dependencies]
dev = ["pytest>=8.0", "pytest-asyncio>=0.23"]

[tool.pytest.ini_options]
asyncio_mode = "auto"
testpaths = ["tests"]
```

- [ ] **Step 2: Create package init + test infrastructure**

`Pipeline/src/tftmac_pipeline/__init__.py`:
```python
__version__ = "0.1.0"
```

`Pipeline/tests/conftest.py`:
```python
import pytest
from pathlib import Path

@pytest.fixture
def fixtures_dir() -> Path:
    return Path(__file__).parent / "fixtures"
```

`Pipeline/.gitignore`:
```
__pycache__/
*.pyc
.venv/
.pytest_cache/
*.egg-info/
```

- [ ] **Step 3: Verify install + pytest bootstrap**

Run: `cd "/Users/mac/Desktop/TFTTACTICS FOR MACS/Pipeline" && python3 -m venv .venv && .venv/bin/pip install -e ".[dev]"`
Then: `.venv/bin/pytest`
Expected: `collected 0 items` (no tests yet, OK)

- [ ] **Step 4: Commit skeleton**

```bash
cd "/Users/mac/Desktop/TFTTACTICS FOR MACS"
git add Pipeline/pyproject.toml Pipeline/src Pipeline/tests/conftest.py Pipeline/.gitignore
git commit -m "chore(pipeline): bootstrap Python project structure"
```

---

## Task 0.2: TDD Jaccard similarity (5 RED-GREEN cycles)

**Files:**
- Create: `Pipeline/tests/test_jaccard.py`
- Create: `Pipeline/src/tftmac_pipeline/jaccard.py`

**Why Jaccard first**: Foundation cho comp_grouping (`Pipeline/src/tftmac_pipeline/comp_grouping.py`) và threshold tuning script. Pure function (hàm thuần), perfect TDD fit.

**Algorithm refresher** (từ spec §Comp Detection Algorithm Step 2):
```
Jaccard(A, B) = |A ∩ B| / |A ∪ B|
```
Ví dụ concrete: A = {Aatrox, Kai'Sa, Sivir, Yasuo}, B = {Aatrox, Kai'Sa, Sivir, Syndra, Yasuo} → intersect {Aatrox, Kai'Sa, Sivir, Yasuo} = 4 units, union 5 units → Jaccard = 4/5 = 0.80.

### Cycle 1: empty sets

- [ ] **RED: Write failing test**

`Pipeline/tests/test_jaccard.py`:
```python
from tftmac_pipeline.jaccard import jaccard_similarity


def test_jaccard_empty_sets_returns_zero():
    """Empty sets = undefined Jaccard (0/0); contract: return 0.0"""
    assert jaccard_similarity(set(), set()) == 0.0
```

- [ ] **Verify RED**: `.venv/bin/pytest tests/test_jaccard.py -v`
Expected: `ImportError: cannot import name 'jaccard_similarity'`

- [ ] **GREEN: Minimal impl**

`Pipeline/src/tftmac_pipeline/jaccard.py`:
```python
def jaccard_similarity(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 0.0
    return 0.0  # stub, will evolve
```

- [ ] **Verify GREEN**: `.venv/bin/pytest tests/test_jaccard.py -v`
Expected: `1 passed`

### Cycle 2: identical sets

- [ ] **RED: Add test**
```python
def test_jaccard_identical_sets_returns_one():
    units = {"Aatrox", "Sivir", "Kai'Sa"}
    assert jaccard_similarity(units, units) == 1.0
```

- [ ] **Verify RED**: fails (returns 0.0 stub)

- [ ] **GREEN: Evolve**
```python
def jaccard_similarity(a: set[str], b: set[str]) -> float:
    if not a and not b:
        return 0.0
    intersect = len(a & b)
    union = len(a | b)
    return intersect / union if union else 0.0
```

- [ ] **Verify GREEN**: `2 passed`

### Cycle 3: zero overlap

- [ ] **RED**
```python
def test_jaccard_disjoint_sets_returns_zero():
    a = {"Aatrox", "Sivir"}
    b = {"Xerath", "Yasuo"}
    assert jaccard_similarity(a, b) == 0.0
```

- [ ] **Verify RED**: passes (lucky — union=4, intersect=0, 0/4=0.0). ACCEPT pass — test documents expected behavior even though impl already handles. Mark as "characterization test" (test đặc tả hành vi).

### Cycle 4: 66% overlap (below threshold)

- [ ] **RED**
```python
def test_jaccard_67_percent_below_threshold():
    """Spec example: 4-unit intersect, 6-unit union → 4/6 = 0.667"""
    a = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo"}
    b = {"Aatrox", "Kai'Sa", "Sivir", "Syndra", "Yasuo"}
    result = jaccard_similarity(a, b)
    assert abs(result - 0.667) < 0.001  # intersect=4, union=6
```

- [ ] **Verify RED**: passes (impl correct already)

### Cycle 5: 83% overlap (above threshold)

- [ ] **RED**
```python
def test_jaccard_83_percent_above_threshold():
    """Minor variant: 5 of 6 units overlap → 5/6 = 0.833"""
    a = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo"}
    b = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yone"}  # Yasuo→Yone
    result = jaccard_similarity(a, b)
    assert abs(result - 0.833) < 0.001  # intersect=4, union=6 → wait recompute
    # A∩B = {Aatrox, Kai'Sa, Sivir, Xerath} = 4
    # A∪B = {Aatrox, Kai'Sa, Sivir, Xerath, Yasuo, Yone} = 6
    # 4/6 = 0.667 — NOT 0.833. Edit test để accurate.
```

- [ ] **Fix test to accurate 83% example**:
```python
def test_jaccard_83_percent_above_threshold():
    """5 of 6 unique units shared → 5/6 = 0.833"""
    a = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo"}
    b = {"Aatrox", "Kai'Sa", "Sivir", "Xerath", "Yasuo", "Syndra"}
    # A∩B = A (5 units), A∪B = B (6 units) → 5/6 = 0.833
    result = jaccard_similarity(a, b)
    assert abs(result - 0.833) < 0.001
```

- [ ] **Verify passes**: `5 passed`

- [ ] **REFACTOR: Add type hints + docstring**

```python
def jaccard_similarity(a: set[str], b: set[str]) -> float:
    """Compute Jaccard similarity coefficient for two sets of unit IDs.

    Jaccard(A, B) = |A ∩ B| / |A ∪ B|

    Returns 0.0 for two empty sets (contract choice, not mathematical).
    """
    if not a and not b:
        return 0.0
    intersect = len(a & b)
    union = len(a | b)
    return intersect / union if union else 0.0
```

- [ ] **Verify tests still green**: `5 passed`

- [ ] **Commit**
```bash
git add Pipeline/tests/test_jaccard.py Pipeline/src/tftmac_pipeline/jaccard.py
git commit -m "feat(pipeline): add Jaccard similarity with 5-case TDD coverage"
```

---

## Task 0.3: TDD comp signature extraction

**Files:**
- Create: `Pipeline/tests/test_comp_signature.py`
- Create: `Pipeline/src/tftmac_pipeline/comp_signature.py`

**Algorithm refresher** (spec §Step 1): Signature = sorted(units where cost >= 3).join("+")

### Cycle 1: filters out cost < 3 units

- [ ] **RED**
```python
from tftmac_pipeline.comp_signature import extract_signature

def test_signature_filters_cost_below_3():
    """1-2 cost units là filler, không define comp identity."""
    units = [
        {"id": "Kog'Maw", "cost": 1},
        {"id": "Ezreal", "cost": 1},
        {"id": "Jinx", "cost": 2},
        {"id": "Kai'Sa", "cost": 3},
        {"id": "Sivir", "cost": 4},
    ]
    assert extract_signature(units) == "Kai'Sa+Sivir"
```

- [ ] **Verify RED**: ImportError

- [ ] **GREEN**
```python
def extract_signature(units: list[dict]) -> str:
    core = sorted(u["id"] for u in units if u["cost"] >= 3)
    return "+".join(core)
```

- [ ] **Verify GREEN**: 1 pass

### Cycle 2: alphabetical sort stable

- [ ] **RED**
```python
def test_signature_alphabetical_stable():
    """Order-independent: {Sivir, Aatrox} == {Aatrox, Sivir}."""
    a = [{"id": "Sivir", "cost": 4}, {"id": "Aatrox", "cost": 3}]
    b = [{"id": "Aatrox", "cost": 3}, {"id": "Sivir", "cost": 4}]
    assert extract_signature(a) == extract_signature(b)
    assert extract_signature(a) == "Aatrox+Sivir"
```

- [ ] **Verify GREEN passes** (sorted() handles this)

### Cycle 3: empty board

- [ ] **RED**
```python
def test_signature_empty_board_returns_empty_string():
    """Player eliminated round 1, 0 units on board."""
    assert extract_signature([]) == ""
```

- [ ] **Verify GREEN passes**

### Cycle 4: full board concrete example (spec §Ví dụ concrete)

- [ ] **RED**
```python
def test_signature_spec_example():
    """From spec: 8-unit board → 5 core units sorted."""
    units = [
        {"id": "Kog'Maw", "cost": 1},
        {"id": "Ezreal", "cost": 1},
        {"id": "Jinx", "cost": 2},
        {"id": "Kai'Sa", "cost": 3},
        {"id": "Aatrox", "cost": 3},
        {"id": "Sivir", "cost": 4},
        {"id": "Yasuo", "cost": 4},
        {"id": "Xerath", "cost": 5},
    ]
    assert extract_signature(units) == "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo"
```

- [ ] **Verify GREEN**: 4 passed

- [ ] **Commit**
```bash
git add Pipeline/tests/test_comp_signature.py Pipeline/src/tftmac_pipeline/comp_signature.py
git commit -m "feat(pipeline): add comp signature extraction (cost>=3 filter + sort)"
```

---

## Task 0.4: TDD comp grouping với Jaccard threshold

**Files:**
- Create: `Pipeline/tests/test_comp_grouping.py`
- Create: `Pipeline/src/tftmac_pipeline/comp_grouping.py`

**Algorithm refresher** (spec §Step 2-3): Group signatures có Jaccard ≥ threshold, chọn canonical là signature có frequency cao nhất.

### Cycle 1: single signature → 1 group

- [ ] **RED**
```python
from tftmac_pipeline.comp_grouping import group_signatures

def test_single_signature_one_group():
    signatures = ["Aatrox+Sivir+Yasuo"]
    groups = group_signatures(signatures, threshold=0.70)
    assert len(groups) == 1
    assert groups[0]["canonical"] == "Aatrox+Sivir+Yasuo"
    assert groups[0]["frequency"] == 1
```

- [ ] **Verify RED**: ImportError

- [ ] **GREEN: Minimal impl**
```python
from collections import Counter
from tftmac_pipeline.jaccard import jaccard_similarity


def _sig_to_set(signature: str) -> set[str]:
    return set(signature.split("+")) if signature else set()


def group_signatures(signatures: list[str], threshold: float) -> list[dict]:
    counter = Counter(signatures)
    return [{"canonical": sig, "frequency": freq, "variants": [sig]}
            for sig, freq in counter.most_common()]
```

- [ ] **Verify GREEN**: 1 pass

### Cycle 2: identical signatures merge by frequency

- [ ] **RED**
```python
def test_identical_signatures_merge_by_frequency():
    signatures = [
        "Aatrox+Sivir+Yasuo",
        "Aatrox+Sivir+Yasuo",
        "Aatrox+Sivir+Yasuo",
    ]
    groups = group_signatures(signatures, threshold=0.70)
    assert len(groups) == 1
    assert groups[0]["frequency"] == 3
```

- [ ] **Verify GREEN passes** (Counter handles)

### Cycle 3: similar signatures (Jaccard ≥ threshold) merge

- [ ] **RED**
```python
def test_similar_above_threshold_merges():
    """0.83 overlap ≥ 0.70 threshold → merge."""
    signatures = [
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",   # freq 2
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo+Syndra",  # freq 1, 5/6=0.833 overlap
    ]
    groups = group_signatures(signatures, threshold=0.70)
    assert len(groups) == 1
    # Canonical = most frequent
    assert groups[0]["canonical"] == "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo"
    assert groups[0]["frequency"] == 3  # merged total
```

- [ ] **Verify RED**: fails (impl returns 2 groups)

- [ ] **GREEN: Evolve with Jaccard merge logic**
```python
def group_signatures(signatures: list[str], threshold: float) -> list[dict]:
    counter = Counter(signatures)
    # Sort by frequency desc so canonical picked first
    sorted_sigs = counter.most_common()
    groups: list[dict] = []
    for sig, freq in sorted_sigs:
        sig_set = _sig_to_set(sig)
        matched = False
        for group in groups:
            canonical_set = _sig_to_set(group["canonical"])
            if jaccard_similarity(sig_set, canonical_set) >= threshold:
                group["frequency"] += freq
                group["variants"].append(sig)
                matched = True
                break
        if not matched:
            groups.append({"canonical": sig, "frequency": freq, "variants": [sig]})
    return groups
```

- [ ] **Verify GREEN**: 3 passed

### Cycle 4: dissimilar signatures below threshold stay separate

- [ ] **RED**
```python
def test_below_threshold_stays_separate():
    """0.667 < 0.70 threshold → split groups."""
    signatures = [
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
        "Aatrox+Kai'Sa+Sivir+Syndra+Yone",  # 3/7 = 0.429 overlap vs first
    ]
    groups = group_signatures(signatures, threshold=0.70)
    assert len(groups) == 2
```

- [ ] **Verify GREEN passes**: 4 passed

### Cycle 5: threshold tunable parameter

- [ ] **RED**
```python
def test_lower_threshold_merges_more():
    """Same input with 0.40 threshold → all 2 merge into 1 group."""
    signatures = [
        "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
        "Aatrox+Kai'Sa+Sivir+Syndra+Yone",  # 3/7 overlap ~0.43
    ]
    groups_strict = group_signatures(signatures, threshold=0.70)
    groups_loose = group_signatures(signatures, threshold=0.40)
    assert len(groups_strict) == 2
    assert len(groups_loose) == 1
```

- [ ] **Verify GREEN passes**: 5 passed

- [ ] **Commit**
```bash
git add Pipeline/tests/test_comp_grouping.py Pipeline/src/tftmac_pipeline/comp_grouping.py
git commit -m "feat(pipeline): add comp grouping with Jaccard threshold merging"
```

---

## Task 0.5: Write threshold tuning script (Action #4 tool)

**Files:**
- Create: `Pipeline/scripts/tune_jaccard_threshold.py`
- Create: `Pipeline/tests/fixtures/hand_labeled_groups.json` (empty template — founder fills Day 2)

**Purpose**: When founder fetches 100 real matches Day 2, run this script comparing thresholds 0.60 / 0.70 / 0.80 against hand-labels → lock best value.

- [ ] **Step 1: Create hand-label fixture template**

`Pipeline/tests/fixtures/hand_labeled_groups.json`:
```json
{
  "description": "Founder fills Day 2 after fetching 100 Challenger matches. 10 hand-labeled 'obvious same comp' groups.",
  "tft_set": "14",
  "groups": []
}
```

Example entry schema (for founder to follow):
```json
{
  "group_id": "storm-quickdraw",
  "player_signatures": [
    "Aatrox+Kai'Sa+Sivir+Xerath+Yasuo",
    "Aatrox+Kai'Sa+Sivir+Xerath+Yone",
    "Aatrox+Kai'Sa+Sivir+Syndra+Yasuo"
  ]
}
```

- [ ] **Step 2: Create tuning script**

`Pipeline/scripts/tune_jaccard_threshold.py`:
```python
"""Tune Jaccard threshold against hand-labeled comp groups.

Usage: python scripts/tune_jaccard_threshold.py tests/fixtures/hand_labeled_groups.json
"""
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent / "src"))

from tftmac_pipeline.comp_grouping import group_signatures


def agreement_rate(expected_groups: list[list[str]], predicted_groups: list[dict]) -> float:
    """% signatures ended up in same group as hand-labeled."""
    if not expected_groups:
        return 0.0
    sig_to_expected = {sig: i for i, grp in enumerate(expected_groups) for sig in grp}
    sig_to_predicted = {sig: i for i, grp in enumerate(predicted_groups)
                        for sig in grp["variants"]}
    hits = 0
    total = 0
    for expected_grp in expected_groups:
        for i, sig1 in enumerate(expected_grp):
            for sig2 in expected_grp[i+1:]:
                total += 1
                if sig_to_predicted.get(sig1) == sig_to_predicted.get(sig2):
                    hits += 1
    return hits / total if total else 0.0


def main(path: str) -> None:
    data = json.loads(Path(path).read_text())
    expected_groups = [g["player_signatures"] for g in data.get("groups", [])]
    if not expected_groups:
        print("No hand-labeled groups. Fill fixtures first.")
        sys.exit(1)
    all_sigs = [sig for grp in expected_groups for sig in grp]
    print(f"Hand-labeled: {len(expected_groups)} groups, {len(all_sigs)} signatures")
    print()
    for threshold in (0.60, 0.70, 0.80):
        predicted = group_signatures(all_sigs, threshold=threshold)
        rate = agreement_rate(expected_groups, predicted)
        print(f"Threshold {threshold}: {len(predicted)} groups | agreement {rate:.1%}")


if __name__ == "__main__":
    main(sys.argv[1])
```

- [ ] **Step 3: Test script works với empty fixture (negative case)**

Run: `.venv/bin/python scripts/tune_jaccard_threshold.py tests/fixtures/hand_labeled_groups.json`
Expected: `"No hand-labeled groups. Fill fixtures first."` + exit 1

- [ ] **Step 4: Commit**
```bash
git add Pipeline/scripts/tune_jaccard_threshold.py Pipeline/tests/fixtures/hand_labeled_groups.json
git commit -m "feat(pipeline): add Jaccard threshold tuning script + fixture template"
```

---

## Task 0.6: TDD install.sh với bats

**Files:**
- Create: `Distribution/install.sh`
- Create: `Distribution/tests/test_install.bats`

**Why bats**: bats-core (`brew install bats-core`) = standard bash TDD framework. Install.sh là shell script với 7 steps, testable với mocks cho `curl`/`hdiutil`/`cp`.

**Scope caveat**: Full install.sh E2E test needs actual .dmg (chưa có ở Phase 0). Phase 0 scope = write script + test **argument parsing** + **dry-run mode** + **error handling paths**. Full integration test moves to Phase 3.

### Cycle 1: script exists + executable

- [ ] **RED**
```bash
# Distribution/tests/test_install.bats
#!/usr/bin/env bats

setup() {
    INSTALL_SCRIPT="${BATS_TEST_DIRNAME}/../install.sh"
}

@test "install.sh exists and is executable" {
    [ -x "$INSTALL_SCRIPT" ]
}
```

- [ ] **Verify RED**: `bats Distribution/tests/test_install.bats` — fails (file not exists)

- [ ] **GREEN: Minimal script**
```bash
# Distribution/install.sh
#!/bin/bash
set -euo pipefail
echo "install.sh stub"
```

Then: `chmod +x Distribution/install.sh`

- [ ] **Verify GREEN**: `bats ...` — 1 passed

### Cycle 2: --help flag

- [ ] **RED**
```bash
@test "install.sh --help prints usage" {
    run "$INSTALL_SCRIPT" --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"Usage:"* ]]
    [[ "$output" == *"TFTMac"* ]]
}
```

- [ ] **Verify RED**: fails (stub doesn't print usage)

- [ ] **GREEN**
```bash
#!/bin/bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--help]

Installs TFTMac.app to /Applications with Gatekeeper whitelist.
Requires sudo for spctl --add step.

Options:
  --dry-run    Print steps without executing
  --help       Show this help
EOF
}

if [[ "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

echo "install.sh stub"
```

- [ ] **Verify GREEN**: 2 passed

### Cycle 3: --dry-run prints expected steps

- [ ] **RED**
```bash
@test "install.sh --dry-run prints all 7 install steps without executing" {
    run "$INSTALL_SCRIPT" --dry-run
    [ "$status" -eq 0 ]
    [[ "$output" == *"[1/7] Download"* ]]
    [[ "$output" == *"[2/7] Mount"* ]]
    [[ "$output" == *"[3/7] Copy"* ]]
    [[ "$output" == *"[4/7] xattr -cr"* ]]
    [[ "$output" == *"[5/7] spctl --add"* ]]
    [[ "$output" == *"[6/7] Eject"* ]]
    [[ "$output" == *"[7/7] Launch"* ]]
}
```

- [ ] **Verify RED**: fails

- [ ] **GREEN: Full dry-run impl**
```bash
#!/bin/bash
set -euo pipefail

RELEASE_URL="${TFTMAC_RELEASE_URL:-https://github.com/OWNER/tft-mac/releases/latest/download/TFTMac.dmg}"
MOUNT_POINT="/Volumes/TFTMac"
APP_PATH="/Applications/TFTMac.app"
DMG_TMP="/tmp/TFTMac.dmg"

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--help]

Installs TFTMac.app to /Applications with Gatekeeper whitelist.
Requires sudo for spctl --add step.

Options:
  --dry-run    Print steps without executing
  --help       Show this help
EOF
}

DRY_RUN=0
case "${1:-}" in
    --help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
esac

run_or_echo() {
    if (( DRY_RUN )); then
        echo "DRY: $*"
    else
        "$@"
    fi
}

echo "[1/7] Download DMG → $DMG_TMP"
run_or_echo curl -fL "$RELEASE_URL" -o "$DMG_TMP"

echo "[2/7] Mount DMG → $MOUNT_POINT"
run_or_echo hdiutil attach "$DMG_TMP" -nobrowse

echo "[3/7] Copy app → $APP_PATH"
run_or_echo cp -R "$MOUNT_POINT/TFTMac.app" /Applications/

echo "[4/7] xattr -cr (remove quarantine recursively)"
run_or_echo xattr -cr "$APP_PATH"

echo "[5/7] spctl --add (Gatekeeper whitelist, requires sudo)"
run_or_echo sudo spctl --add --label "TFTMac" "$APP_PATH"

echo "[6/7] Eject DMG"
run_or_echo hdiutil detach "$MOUNT_POINT"
run_or_echo rm -f "$DMG_TMP"

echo "[7/7] Launch app"
run_or_echo open "$APP_PATH"
echo "✓ Done. Menu bar icon should appear. Cmd+Shift+T để mở."
```

- [ ] **Verify GREEN**: 3 passed

### Cycle 4: unknown arg exits non-zero

- [ ] **RED**
```bash
@test "install.sh unknown arg exits 1 with error message" {
    run "$INSTALL_SCRIPT" --nonsense-flag
    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown arg"* ]]
}
```

- [ ] **Verify GREEN**: 4 passed (case statement handles)

### Cycle 5: shellcheck clean

- [ ] **RED**
```bash
@test "install.sh passes shellcheck" {
    run shellcheck "$INSTALL_SCRIPT"
    [ "$status" -eq 0 ]
}
```

- [ ] **Verify RED/GREEN**: Run `shellcheck Distribution/install.sh` manually first, fix warnings iteratively until green.
Common fixes: quote vars, use `[[ ]]` not `[ ]`, prefer `$(...)` over backticks.

- [ ] **Commit**
```bash
git add Distribution/install.sh Distribution/tests/test_install.bats
chmod +x Distribution/install.sh
git commit -m "feat(dist): add install.sh with bats test coverage (5 cases)"
```

---

## Task 0.7: Founder manual actions (track only, not TDD)

**These cannot be TDD-automated. Track completion manually here.**

- [ ] **Action #1 — Apply Riot Production key** (founder, 15 min)
  - Visit `https://developer.riotgames.com/app-type`
  - Select "Personal API Key" application (or "Production" nếu có project description)
  - Fill: usage description = "TFT Mac companion app, fetching Challenger match data for tier list aggregation. 10 initial testers, low-volume (~9500 req per 12h)."
  - Submit form. Save confirmation screenshot to `docs/riot-prod-key-application.png`
  - **Track**: queue for 1-4 week approval. Continue với Dev key meanwhile.

- [ ] **Action #3 — Riot API data structure verification** (founder, 2h)
  - Apply Dev key: `https://developer.riotgames.com/` → "Regenerate API Key"
  - Save to `~/.tftmac/env`: `RIOT_API_KEY_DEV=RGAPI-xxx`; `chmod 600 ~/.tftmac/env`
  - Fetch 20-30 Challenger PUUIDs (any region): `GET /tft/league/v1/challenger` → pick top 20
  - For each PUUID: `GET /tft/match/v1/matches/by-puuid/{puuid}/ids?count=5` → get 5 match IDs
  - For 100 match IDs (deduped): `GET /tft/match/v1/matches/{match_id}`
  - **Inspect** `participant.units[]` + `participant.augments[]` — confirm schema matches spec
  - **Output**: `docs/pre-spike-api-verify.md` với sample response + notes

- [ ] **Action #4 — Hand-label 10 comp groups + run tuning script**
  - Use 100 matches từ Action #3. Extract all player boards, compute signatures via `extract_signature()`.
  - Open result trong spreadsheet. Eyeball pick 10 "obvious same comp" groups (30-50 signatures total).
  - Fill `Pipeline/tests/fixtures/hand_labeled_groups.json` với groups array.
  - Run: `python scripts/tune_jaccard_threshold.py tests/fixtures/hand_labeled_groups.json`
  - Output: Agreement rates for 0.60 / 0.70 / 0.80.
  - **Decision gate**: Pick threshold with highest agreement. If all <80% → fall back to carry-signature algorithm (documented as `detect_via_carry_signature()` in Phase 2).
  - **Output**: `docs/pre-spike-algo-tuning.md` với numbers + locked threshold.

- [x] **Action #5 — P2 fullscreen overlay test** (founder, 15 min) — **SKIPPED**, stub doc created (see `docs/pre-spike-p2-overlay-test.md`). Deferred to v0.2.
  - Launch TFT on Mac → Settings → Fullscreen mode
  - Start 1 match
  - Press Cmd+Space (Spotlight) — hiện được trên TFT fullscreen không? Screenshot.
  - Install Raycast (free) → hotkey → hiện được không? Screenshot.
  - **Output**: `docs/pre-spike-p2-overlay-test.md` với screenshots + conclusion (exclusive vs borderless). NOT v0.1 blocker — data cho v0.2.

- [x] **Action #6 — Wireframe Standard card** (founder+CC, 2-3h) — **DONE** 2026-04-24. Stitch v2 generated → `docs/wireframes/popover-styleA-v2.png` + locked dimensions in `docs/wireframe-v0.1-standard-card.md`.
  - Run `/design-consultation` trong Claude Code session
  - Input: spec §Feature 1 + NFR card dims
  - Output wireframe → lock layout decisions (width 400px? 480px? card height?)
  - Run `/design-shotgun` với approved wireframe
  - **Output**: `docs/wireframe-v0.1-standard-card.md` + PNG mockups trong `docs/wireframes/`

---

## Task 0.8: XCUITest compatibility spike (CEO review F6.1)

**Files:**
- Create: `docs/pre-spike-xcuitest-menubar.md`

**Why**: Phase 1 Task 1.10 planned XCUITest để measure popover open latency ≤300ms. Nhưng app là LSUIElement=true (menu-bar-only, no Dock icon) — XCUITest default `app.launch()` workflow giả định Dock app. Chưa biết có support không. Nếu un-testable → fallback manual stopwatch (bấm đồng hồ tay) = less rigorous. Cheap insurance (30min) vs potential Phase 1 rework.

- [ ] **Step 1: Create throwaway test project** (Xcode → macOS → App, LSUIElement=true Info.plist)
- [ ] **Step 2: Try XCUITest scaffold**:
```swift
import XCTest

class MenuBarLaunchTest: XCTestCase {
    func testAppLaunches() throws {
        let app = XCUIApplication()
        app.launch()  // Does this work for LSUIElement=true?
        XCTAssertTrue(app.state == .runningForeground || app.state == .runningBackground)
    }
}
```
- [ ] **Step 3: Run** `xcodebuild test -scheme ThrowawayTest -destination 'platform=macOS'`
- [ ] **Step 4: Write findings** to `docs/pre-spike-xcuitest-menubar.md`:
  - Does `app.launch()` work? [YES/NO + error message if NO]
  - Can `app.menuBars.element(boundBy: 0)` reach status item? [YES/NO]
  - Performance metric `XCTApplicationLaunchMetric()` viable? [YES/NO]
  - **Decision**: [Proceed với XCUITest / Fallback manual stopwatch + note trong Phase 1]

**Effort**: 30 min spike, delete throwaway project after.

---

## Success Criteria (Phase 0 gate)

Phase 0 COMPLETE when ALL of:

- [ ] Pipeline Python project bootstraps (`.venv/bin/pytest` runs)
- [ ] Jaccard similarity: 5 tests green
- [ ] Comp signature: 4 tests green
- [ ] Comp grouping: 5 tests green
- [ ] Threshold tuning script exists + runs with empty fixture
- [ ] install.sh: 5 bats tests green + shellcheck clean (bats install deferred, syntax + help + dry-run smoke done)
- [ ] Task 0.8: XCUITest + LSUIElement verified — `docs/pre-spike-xcuitest-menubar.md` exists
- [ ] Action #1: Production key applied (founder confirms screenshot saved)
- [ ] Action #3: `docs/pre-spike-api-verify.md` exists
- [ ] Action #4: `docs/pre-spike-algo-tuning.md` exists với locked threshold
- [x] Action #5: `docs/pre-spike-p2-overlay-test.md` exists (SKIPPED stub)
- [x] **Action #6: `docs/wireframe-v0.1-standard-card.md` exists** ← HARD GATE cho Phase 1 Task 1.9 (PASSED 2026-04-24)

## Next Phase

→ `phase-01-weekend-1-app-scaffold.md` — unlocked khi Phase 0 gate passes.
