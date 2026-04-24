"""Comp signature extraction (spec §Comp Detection Algorithm Step 1)."""


def extract_signature(units: list[dict]) -> str:
    """Return canonical signature string từ player's board.

    Spec: signature = sorted(units where cost >= 3).join("+")

    Ví dụ: board 8 units → filter cost>=3 → 5 core units → alphabetical sort:
    `"Aatrox+Kai'Sa+Sivir+Xerath+Yasuo"`.
    """
    core = sorted(u["id"] for u in units if u["cost"] >= 3)
    return "+".join(core)
