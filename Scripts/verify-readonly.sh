#!/usr/bin/env bash
# Run this script before launching Pulse and after running for N minutes.
# Captures sha256 + mtime of all source files; second run compares.
set -euo pipefail

MODE="${1:?Usage: verify-readonly.sh [snapshot|compare]}"
SNAPSHOT_FILE="${HOME}/.pulse-readonly-snapshot.json"

source_paths=(
  "${HOME}/Desktop/new_heterotopias/CLAUDE.md"
  "${HOME}/Desktop/heterotopias-next/CLAUDE.md"
  "${HOME}/Desktop/md-editor"
  "${HOME}/Desktop/pots-archive/CLAUDE.md"
  "${HOME}/Desktop/新大眾文藝/CLAUDE.md"
  "${HOME}/Desktop/矽盾週報/CLAUDE.md"
  "${HOME}/Desktop/文化與技術三部曲/CLAUDE.md"
  "${HOME}/Desktop/writing-agent"
  "${HOME}/Desktop/中國技術道路_2008_2028/CLAUDE.md"
)

snapshot() {
  local out="["
  local first=1
  for p in "${source_paths[@]}"; do
    [[ -f "$p" ]] || continue
    local sha=$(shasum -a 256 "$p" | awk '{print $1}')
    local mtime=$(stat -f %m "$p")
    [[ $first -eq 0 ]] && out+=","
    out+="{\"path\":\"$p\",\"sha\":\"$sha\",\"mtime\":$mtime}"
    first=0
  done
  out+="]"
  echo "$out" > "$SNAPSHOT_FILE"
  echo "snapshot written: $SNAPSHOT_FILE"
}

compare() {
  [[ -f "$SNAPSHOT_FILE" ]] || { echo "no snapshot, run 'snapshot' first"; exit 1; }
  local fail=0
  for p in "${source_paths[@]}"; do
    [[ -f "$p" ]] || continue
    local sha=$(shasum -a 256 "$p" | awk '{print $1}')
    local mtime=$(stat -f %m "$p")
    local snap_sha=$(jq -r ".[] | select(.path==\"$p\") | .sha" "$SNAPSHOT_FILE")
    local snap_mtime=$(jq -r ".[] | select(.path==\"$p\") | .mtime" "$SNAPSHOT_FILE")
    if [[ "$sha" != "$snap_sha" || "$mtime" != "$snap_mtime" ]]; then
      echo "MODIFIED: $p"
      echo "   sha:   $snap_sha -> $sha"
      echo "   mtime: $snap_mtime -> $mtime"
      fail=1
    else
      echo "OK: $p"
    fi
  done
  exit $fail
}

case "$MODE" in
  snapshot) snapshot ;;
  compare)  compare ;;
  *) echo "Usage: $0 [snapshot|compare]"; exit 1 ;;
esac
