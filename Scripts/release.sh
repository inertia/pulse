#!/usr/bin/env bash
# Tag + push + GitHub release with bundle ID safety check.
# Refuses to publish if the public dmg's bundle ID is wrong (e.g. internal build).
set -euo pipefail

VERSION="${1:?Usage: release.sh <version>}"
DMG="build/Pulse-${VERSION}.dmg"
EXPECTED_BUNDLE_ID="com.huangsunquan.pulse"

if [[ ! -f "$DMG" ]]; then
  echo "Public dmg not found: $DMG"
  echo "Run: ./Scripts/build-dmg.sh ${VERSION} public  (or both)"
  exit 1
fi

# Mount dmg and inspect bundle ID. hdiutil output is tab-separated; the mount
# path may contain spaces (e.g. "/Volumes/Pulse 0.1.0"), so we split on \t.
MOUNT=$(hdiutil attach -nobrowse -readonly "$DMG" \
  | awk -F'\t' '/\/Volumes\// {sub(/^ +/, "", $3); print $3; exit}')
trap "hdiutil detach \"$MOUNT\" >/dev/null 2>&1 || true" EXIT

ACTUAL_BUNDLE_ID=$(plutil -p "$MOUNT/Pulse.app/Contents/Info.plist" \
  | awk -F'"' '/CFBundleIdentifier/ {print $4}')

if [[ "$ACTUAL_BUNDLE_ID" != "$EXPECTED_BUNDLE_ID" ]]; then
  echo "Bundle ID mismatch: expected $EXPECTED_BUNDLE_ID, got $ACTUAL_BUNDLE_ID"
  echo "This dmg may be the internal build. Refusing to publish."
  exit 1
fi
echo "Bundle ID correct: $ACTUAL_BUNDLE_ID"

# Detach before further git/gh actions
hdiutil detach "$MOUNT" >/dev/null
trap - EXIT

# Tag (annotated)
git tag -a "v${VERSION}" -F - <<EOF
v${VERSION} — Pulse 首版

跨專案 todo / done 自動 monitor menubar app（macOS 14+）。

支援格式：CLAUDE.md / AGENTS.md / GEMINI.md / git log conventional commits
通用版 onboarding 自動掃常見路徑找 source。讀取，不寫回。
EOF
git push origin "v${VERSION}"

# GitHub release (public dmg only — internal build stays local)
gh release create "v${VERSION}" \
  --title "Pulse v${VERSION}" \
  --notes-file CHANGELOG.md \
  "$DMG"
