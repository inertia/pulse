#!/usr/bin/env bash
set -e
xcodebuild -project Pulse.xcodeproj -scheme Pulse \
  -configuration Debug-Public \
  -destination 'platform=macOS' \
  test
