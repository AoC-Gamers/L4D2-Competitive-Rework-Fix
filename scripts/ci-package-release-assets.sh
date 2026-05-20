#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${RELEASE_BASENAME:?RELEASE_BASENAME is required}"
python3 "$ROOT_DIR/scripts/package-release.py" --root "$ROOT_DIR" --basename "$RELEASE_BASENAME"
