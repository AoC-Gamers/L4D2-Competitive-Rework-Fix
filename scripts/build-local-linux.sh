#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PACKAGE_MAP_PATH="$ROOT_DIR/plugin-package-map.json"
SOURCE_ROOT="$ROOT_DIR/addons/sourcemod"
SCRIPTING_DIR="$SOURCE_ROOT/scripting"
INCLUDE_DIR="$SCRIPTING_DIR/include"
TRANSLATIONS_DIR="$SOURCE_ROOT/translations"
OUTPUT_ROOT="${OUTPUT_ROOT:-build-linux}"
BUILD_ROOT="$ROOT_DIR/$OUTPUT_ROOT"
ARTIFACT_ROOT="$BUILD_ROOT/addons/sourcemod"
PLUGINS_ROOT="$ARTIFACT_ROOT/plugins"
COMPILE_LOG="$BUILD_ROOT/compile.log"
TMP_LOG="$ROOT_DIR/.tmp/build-linux-compile.log"
SPCOMP_BIN="${SPCOMP_BIN:-$ROOT_DIR/.tmp/sourcemod-linux/addons/sourcemod/scripting/spcomp}"
SOURCEMOD_INCLUDE_DIR="$(cd "$(dirname "$SPCOMP_BIN")/include" && pwd)"

if [[ ! -f "$SPCOMP_BIN" ]]; then
  echo "spcomp not found at $SPCOMP_BIN" >&2
  exit 1
fi

if [[ ! -f "$PACKAGE_MAP_PATH" ]]; then
  echo "Missing plugin-package-map.json at $PACKAGE_MAP_PATH" >&2
  exit 1
fi

classify_plugin_dir() {
  local plugin_stem="$1"
  python3 - "$PACKAGE_MAP_PATH" "$plugin_stem" <<'PY'
import json
import sys

map_path, plugin_stem = sys.argv[1], sys.argv[2]
with open(map_path, "r", encoding="utf-8") as fh:
    data = json.load(fh)

if plugin_stem in data.get("anticheat", []):
    print("anticheat")
elif plugin_stem in data.get("fixes", []):
    print("fixes")
else:
    print("optional")
PY
}

rm -rf "$BUILD_ROOT"
mkdir -p "$PLUGINS_ROOT/anticheat" "$PLUGINS_ROOT/fixes" "$PLUGINS_ROOT/optional"
mkdir -p "$(dirname "$TMP_LOG")"
: > "$TMP_LOG"

mapfile -t plugin_sources < <(find "$SCRIPTING_DIR" -maxdepth 1 -type f -name '*.sp' | sort)

if [[ "${#plugin_sources[@]}" -eq 0 ]]; then
  echo "No SourceMod plugin sources found in $SCRIPTING_DIR" >&2
  exit 1
fi

for source_file in "${plugin_sources[@]}"
do
  plugin_name="$(basename "$source_file")"
  plugin_stem="${plugin_name%.sp}"
  plugin_dir="$(classify_plugin_dir "$plugin_stem")"
  output_file="$PLUGINS_ROOT/$plugin_dir/${plugin_stem}.smx"

  echo "Compiling $plugin_name -> plugins/$plugin_dir/${plugin_stem}.smx"
  "$SPCOMP_BIN" \
    "$source_file" \
    -i"$INCLUDE_DIR" \
    -i"$SCRIPTING_DIR" \
    -i"$SOURCEMOD_INCLUDE_DIR" \
    -o"$output_file" \
    2>&1 | tee -a "$TMP_LOG"
done

cp -R "$SCRIPTING_DIR" "$ARTIFACT_ROOT/"
cp -R "$TRANSLATIONS_DIR" "$ARTIFACT_ROOT/"

echo
echo "Linux local build completed in: $BUILD_ROOT"
