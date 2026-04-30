#!/usr/bin/env bash
# Build Pulse.app from source and install it to /Applications.
#
# Locally-built apps inherit your keychain trust, so they don't trigger
# the Gatekeeper "unidentified developer" warning the way unsigned dmg
# downloads do. This is the recommended install path for anyone who
# would rather build from source than right-click → Open an unsigned
# binary.
#
# Usage:
#   ./Scripts/build-and-install.sh             # Public build (Pulse.app)
#   ./Scripts/build-and-install.sh internal    # Personal build (Pulse Internal.app)
#
# Requires: macOS 14+, Xcode 15+ (or Command Line Tools), xcodegen
#   brew install xcodegen

set -euo pipefail

KIND="${1:-public}"

case "$KIND" in
  public)
    CONFIG="Release-Public"
    APP_NAME="Pulse"
    ;;
  internal)
    CONFIG="Release-Internal"
    APP_NAME="Pulse Internal"
    ;;
  *)
    echo "Unknown build kind: $KIND" >&2
    echo "Usage: $0 [public|internal]" >&2
    exit 2
    ;;
esac

# Ensure we're at the repo root.
cd "$(dirname "$0")/.."

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen not found. Install with:  brew install xcodegen" >&2
  exit 1
fi

echo "→ Generating Xcode project from project.yml…"
xcodegen generate >/dev/null

echo "→ Building $CONFIG (this takes ~30-60s on first run, faster on rebuild)…"
# Sign with the self-signed cert provisioned by Scripts/setup-signing-cert.sh
# (CODE_SIGN_IDENTITY is set in xcconfig/Shared.xcconfig). Stable signing keeps
# macOS TCC FDA grants persistent across rebuilds.
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  build >/tmp/pulse-build.log 2>&1 || {
    echo "Build failed. Last 20 lines of log:" >&2
    tail -20 /tmp/pulse-build.log >&2
    exit 1
  }

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData \
  -name "${APP_NAME}.app" \
  -path "*${CONFIG}*" \
  -not -path "*Index.noindex*" \
  | head -1)

if [[ -z "$APP_PATH" || ! -d "$APP_PATH" ]]; then
  echo "Built app not found in DerivedData (looked for ${APP_NAME}.app under ${CONFIG})" >&2
  exit 1
fi

echo "→ Built: $APP_PATH"
echo "→ Replacing /Applications/${APP_NAME}.app…"

# Quit any running instance so the cp doesn't ETXTBSY.
pkill -9 -f "${APP_NAME}" 2>/dev/null || true
sleep 1

rm -rf "/Applications/${APP_NAME}.app"
cp -R "$APP_PATH" /Applications/

# Locally-built apps don't carry com.apple.quarantine, but if the build
# was previously installed from a downloaded dmg, the attribute could
# linger on the directory. Strip just in case.
xattr -dr com.apple.quarantine "/Applications/${APP_NAME}.app" 2>/dev/null || true

echo "→ Launching ${APP_NAME}.app…"
open "/Applications/${APP_NAME}.app"
sleep 1

if pgrep -f "${APP_NAME}" >/dev/null; then
  echo
  echo "✓ ${APP_NAME} installed and running. Look for the menubar icon (amber pulse spike)."
else
  echo "Installed but process didn't start. Try opening ${APP_NAME}.app manually." >&2
  exit 1
fi
