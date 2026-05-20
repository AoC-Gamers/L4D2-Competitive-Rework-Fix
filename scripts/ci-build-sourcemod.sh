#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Resolving SourceMod dependencies through make..."
make -C "$ROOT_DIR" deps-smx PYTHON=python3 SOURCEMOD_VERSION="${SOURCEMOD_VERSION:-1.12}" SMX_PLATFORM=linux

echo "Building Linux SMX through make..."
make -C "$ROOT_DIR" build-smx PYTHON=python3 SPCOMP="deps/sourcemod-linux/addons/sourcemod/scripting/spcomp"

echo "Packaging Linux SMX tree through make..."
make -C "$ROOT_DIR" package-smx PYTHON=python3
