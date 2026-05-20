#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"

echo "Resolving Linux SourceMod dependencies through make..."
make -C "$ROOT_DIR" deps-linux PYTHON3=python3 SOURCEMOD_VERSION="${SOURCEMOD_VERSION:-1.12}"

echo "Building Linux artifact through make..."
make -C "$ROOT_DIR" artifact-linux PYTHON3=python3 LINUX_SPCOMP="deps/sourcemod-linux/addons/sourcemod/scripting/spcomp"
