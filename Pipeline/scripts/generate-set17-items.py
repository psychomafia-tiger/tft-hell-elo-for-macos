"""Generate App/TFTMac/Resources/set17-items.json from CommunityDragon en_us.json.

Usage: python3 Pipeline/scripts/generate-set17-items.py

Filters items by:
  - apiName starts with 'TFT_Item_'
  - excludes augment/anomaly/component prefixes
  - excludes pure components (no icon path)

Auto-classifies itemClass by keyword scan of `desc` field. Heuristic — manual
override for known items via OVERRIDES dict.
"""
from __future__ import annotations
import json
import urllib.request
from pathlib import Path

CDRAGON_URL = "https://raw.communitydragon.org/latest/cdragon/tft/en_us.json"
OUTPUT_PATH = (
    Path(__file__).parent.parent.parent / "App/TFTMac/Resources/set17-items.json"
)

# Manual class overrides for items where keyword heuristic fails or for canonical
# classification clarity. Extend as new items surface in production data.
OVERRIDES = {
    "TFT_Item_GargoyleStoneplate": "tank",
    "TFT_Item_BrambleVest":        "tank",
    "TFT_Item_DragonsClaw":        "tank",
    "TFT_Item_Warmogs":            "tank",
    "TFT_Item_WarmogsArmor":       "tank",
    "TFT_Item_SunfireCape":        "tank",
    "TFT_Item_TitansResolve":      "tank",
    "TFT_Item_RedBuff":            "tank",
    "TFT_Item_Crownguard":         "tank",
    "TFT_Item_Steadfast":          "tank",
    "TFT_Item_SteadfastHeart":     "tank",
    "TFT_Item_InfinityEdge":       "ad",
    "TFT_Item_LastWhisper":        "ad",
    "TFT_Item_Bloodthirster":      "ad",
    "TFT_Item_GiantSlayer":        "ad",
    "TFT_Item_Deathblade":         "ad",
    "TFT_Item_GuinsoosRageblade":  "ad",
    "TFT_Item_RunaansHurricane":   "ad",
    "TFT_Item_Runaans":            "ad",
    "TFT_Item_StatikkShiv":        "ad",
    "TFT_Item_HandOfJustice":      "ad",
    "TFT_Item_TitanicHydra":       "ad",
    "TFT_Item_RabadonsDeathcap":   "ap",
    "TFT_Item_JeweledGauntlet":    "ap",
    "TFT_Item_ArchangelsStaff":    "ap",
    "TFT_Item_BlueBuff":           "ap",
    "TFT_Item_HextechGunblade":    "ap",
    "TFT_Item_IonicSpark":         "ap",
    "TFT_Item_Morellonomicon":     "ap",
    "TFT_Item_Shojin":             "ap",
    "TFT_Item_SpearOfShojin":      "ap",
    "TFT_Item_NashorsTooth":       "ap",
    "TFT_Item_VoidStaff":          "ap",
    "TFT_Item_AdaptiveHelm":       "utility",
    "TFT_Item_Redemption":         "utility",
    "TFT_Item_ZekesHerald":        "utility",
    "TFT_Item_Zephyr":             "utility",
    "TFT_Item_ProtectorsVow":      "utility",
    "TFT_Item_Quicksilver":        "utility",
    "TFT_Item_Edgeofnight":        "utility",
    "TFT_Item_EdgeOfNight":        "utility",
}


def classify(desc: str) -> str:
    """Heuristic itemClass from item description text."""
    if not desc:
        return "unknown"
    d = desc.upper()
    has_armor = any(kw in d for kw in ["ARMOR", "MAGIC RESIST", "@MAGICRESIST", "@HEALTH"])
    has_ad    = any(kw in d for kw in ["ATTACK DAMAGE", "@AD", "CRITICAL STRIKE", "ATTACK SPEED"])
    has_ap    = any(kw in d for kw in ["ABILITY POWER", "@AP", "MANA"])
    has_util  = any(kw in d for kw in ["HEAL", "SHIELD", "ALLIES", "TEAM"])
    if has_armor and not has_ad and not has_ap:
        return "tank"
    if has_ad and not has_ap:
        return "ad"
    if has_ap:
        return "ap"
    if has_util:
        return "utility"
    return "unknown"


def icon_to_token(icon_path: str) -> str:
    """`ASSETS/Maps/TFT/Icons/Items/Hexcore/TFT_Item_GargoyleStoneplate.TFT_Set13.tex`
    → `tft_item_gargoylestoneplate.tft_set13`. App prepends URL base + `.png`.
    """
    if not icon_path:
        return ""
    filename = icon_path.split("/")[-1]
    return filename.replace(".tex", "").replace(".TEX", "").lower()


def main() -> None:
    print(f"Fetching {CDRAGON_URL}...")
    req = urllib.request.Request(CDRAGON_URL, headers={"User-Agent": "Mozilla/5.0"})
    raw = urllib.request.urlopen(req).read()
    data = json.loads(raw)

    items = data.get("items", [])
    print(f"Total items in en_us.json: {len(items)}")

    EXCLUDE_PREFIXES = (
        "TFT_Item_Augment_",
        "TFT17_EkkoOffering_",
        "TFT_Item_Component_",
        "TFT_Item_EmptyBag",
    )
    output = {}
    for item in items:
        api_name = item.get("apiName", "")
        if not api_name.startswith("TFT_Item_"):
            continue
        if any(api_name.startswith(p) for p in EXCLUDE_PREFIXES):
            continue
        icon = item.get("icon")
        if not icon:
            continue
        token = icon_to_token(icon)
        if not token:
            continue
        # Skip items with null/empty name (e.g. TFT_Item_Blank placeholders)
        name = item.get("name")
        if not name:
            continue
        item_class = OVERRIDES.get(api_name) or classify(item.get("desc", ""))
        output[api_name] = {
            "displayName": name,
            "iconToken":   token,
            "itemClass":   item_class,
        }

    print(f"Filtered to {len(output)} items")
    OUTPUT_PATH.write_text(
        json.dumps(output, sort_keys=True, indent=2, ensure_ascii=False)
    )
    print(f"Wrote {OUTPUT_PATH}")

    from collections import Counter
    dist = Counter(v["itemClass"] for v in output.values())
    print(f"Class distribution: {dict(dist)}")


if __name__ == "__main__":
    main()
