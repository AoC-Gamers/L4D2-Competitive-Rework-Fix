#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$ROOT_DIR/.tmp"
WORK_DIR="$TMP_DIR/sourcemod-linux"
ARCHIVE_PATH="$TMP_DIR/sourcemod-linux.tar.gz"
SOURCEMOD_VERSION="${SOURCEMOD_VERSION:-1.12}"
ARCHIVE_URL="https://www.sourcemod.net/latest.php?os=linux&version=${SOURCEMOD_VERSION}"

rm -rf "$WORK_DIR"
mkdir -p "$TMP_DIR"

echo "Downloading SourceMod for Linux from: $ARCHIVE_URL"
curl -fsSL "$ARCHIVE_URL" -o "$ARCHIVE_PATH"
tar -xzf "$ARCHIVE_PATH" -C "$WORK_DIR"

echo "Linux dependencies ready in: $WORK_DIR"
