#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:?Usage: build-dmg.sh <version> [internal|public|both]}"
BUILD_KIND="${2:-both}"

build_one() {
  local kind="$1"
  local config
  local suffix
  if [[ "$kind" == "internal" ]]; then
    config="Release-Internal"
    suffix="-internal"
  else
    config="Release-Public"
    suffix=""
  fi
  local dmg="build/Pulse-${VERSION}${suffix}.dmg"

  rm -rf "build/staging-${kind}"
  mkdir -p "build/staging-${kind}"

  # Sign with self-signed cert from xcconfig (see setup-signing-cert.sh).
  xcodebuild -project Pulse.xcodeproj -scheme Pulse \
    -configuration "$config" \
    -derivedDataPath "build/dd-${kind}" \
    -destination 'platform=macOS' \
    clean build

  cp -R "build/dd-${kind}/Build/Products/${config}/"*.app "build/staging-${kind}/"
  ln -s /Applications "build/staging-${kind}/Applications"

  hdiutil create -volname "Pulse ${VERSION}" \
    -srcfolder "build/staging-${kind}" \
    -ov -format UDZO "$dmg"

  echo "OK: $dmg"
}

case "$BUILD_KIND" in
  internal) build_one internal ;;
  public)   build_one public ;;
  both)     build_one public; build_one internal ;;
  *) echo "Unknown kind: $BUILD_KIND"; exit 1 ;;
esac

# Clean all xcodebuild leftovers in build/ — keep only *.dmg.
# Otherwise build/dd-{kind}/ (~200MB each) + build/staging-{kind}/Pulse.app
# accumulate and Spotlight-index Pulse.app from staging/, polluting Launchpad.
find build -mindepth 1 -maxdepth 1 ! -name "*.dmg" -exec rm -rf {} +
