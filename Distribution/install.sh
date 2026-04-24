#!/bin/bash
# TFTMac installer — Weekend 0 Assignment #2 (eng review §1.2)
# One-command onboarding với xattr -cr + spctl --add để bypass Gatekeeper friction.
#
# Usage:
#   curl -fL https://github.com/<owner>/tft-mac/releases/latest/download/install.sh | bash
#   ./install.sh --dry-run    # Print steps without executing
#   ./install.sh --help       # Show usage

set -euo pipefail

RELEASE_URL="${TFTMAC_RELEASE_URL:-https://github.com/OWNER/tft-mac/releases/latest/download/TFTMac.dmg}"
MOUNT_POINT="/Volumes/TFTMac"
APP_PATH="/Applications/TFTMac.app"
DMG_TMP="/tmp/TFTMac.dmg"

usage() {
    cat <<'EOF'
Usage: install.sh [--dry-run] [--help]

Installs TFTMac.app to /Applications with Gatekeeper whitelist.
Requires sudo for spctl --add step (step 5 of 7).

Options:
  --dry-run    Print steps without executing (safe preview)
  --help       Show this help

Environment:
  TFTMAC_RELEASE_URL   Override DMG download URL (default: latest GitHub release)

Rollback on failure:
  rm -rf /Applications/TFTMac.app
  hdiutil detach /Volumes/TFTMac 2>/dev/null || true
  rm -f /tmp/TFTMac.dmg
EOF
}

DRY_RUN=0
case "${1:-}" in
    --help) usage; exit 0 ;;
    --dry-run) DRY_RUN=1 ;;
    "") ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
esac

run_or_echo() {
    if (( DRY_RUN )); then
        echo "DRY: $*"
    else
        "$@"
    fi
}

on_error() {
    local exit_code=$?
    echo "" >&2
    echo "✗ Install failed. Rollback guidance:" >&2
    echo "  rm -rf ${APP_PATH}" >&2
    echo "  hdiutil detach ${MOUNT_POINT} 2>/dev/null || true" >&2
    echo "  rm -f ${DMG_TMP}" >&2
    echo "Then DM founder with error details." >&2
    exit $exit_code
}
trap on_error ERR

echo "[1/7] Download DMG → $DMG_TMP"
run_or_echo curl -fL "$RELEASE_URL" -o "$DMG_TMP"

echo "[2/7] Mount DMG → $MOUNT_POINT"
run_or_echo hdiutil attach "$DMG_TMP" -nobrowse

echo "[3/7] Copy app → $APP_PATH"
run_or_echo cp -R "$MOUNT_POINT/TFTMac.app" /Applications/

echo "[4/7] xattr -cr (remove ALL quarantine attributes recursively)"
run_or_echo xattr -cr "$APP_PATH"

echo "[5/7] spctl --add (Gatekeeper whitelist — requires sudo)"
if (( DRY_RUN )); then
    echo "DRY: sudo spctl --add --label TFTMac $APP_PATH"
else
    sudo spctl --add --label "TFTMac" "$APP_PATH" \
        || echo "  (spctl --add warn: OK on clean Macs, safe to continue)"
fi

echo "[6/7] Eject DMG"
run_or_echo hdiutil detach "$MOUNT_POINT"
run_or_echo rm -f "$DMG_TMP"

echo "[7/7] Launch app"
run_or_echo open "$APP_PATH"

echo ""
echo "✓ TFTMac installed. Menu bar icon should appear."
echo "  Hotkey: Cmd+Shift+T để mở popover."
