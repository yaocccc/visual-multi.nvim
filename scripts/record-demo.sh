#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

for dependency in vhs ttyd ffmpeg; do
  if ! command -v "$dependency" >/dev/null 2>&1; then
    printf '%s is required to record the demo.\n' "$dependency" >&2
    exit 1
  fi
done

vhs demo/demo.tape
