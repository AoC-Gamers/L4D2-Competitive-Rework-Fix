#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${RUNNER_TEMP:-$ROOT_DIR/.tmp}/sourcemod-build"
DIST_DIR="$ROOT_DIR/dist/sourcemod"
ARTIFACT_DIR="$DIST_DIR/artifact"
SOURCEMOD_ARCHIVE_URL="${SOURCEMOD_ARCHIVE_URL:?SOURCEMOD_ARCHIVE_URL is required}"
PACKAGE_MAP_PATH="$ROOT_DIR/plugin-package-map.json"

SOURCE_ROOT="$ROOT_DIR/left4dead2/addons/sourcemod"
SCRIPTING_DIR="$SOURCE_ROOT/scripting"
INCLUDE_DIR="$SCRIPTING_DIR/include"
TRANSLATIONS_DIR="$SOURCE_ROOT/translations"

rm -rf "$WORK_DIR" "$DIST_DIR"
mkdir -p "$WORK_DIR" "$ARTIFACT_DIR"

echo "Downloading SourceMod compiler package..."
curl -fsSL "$SOURCEMOD_ARCHIVE_URL" -o "$WORK_DIR/sourcemod.tar.gz"
tar -xzf "$WORK_DIR/sourcemod.tar.gz" -C "$WORK_DIR"

SOURCEMOD_DIR="$WORK_DIR"
SPCOMP_BIN="$SOURCEMOD_DIR/addons/sourcemod/scripting/spcomp"
SOURCEMOD_INCLUDE_DIR="$SOURCEMOD_DIR/addons/sourcemod/scripting/include"
COMPILE_LOG="$ARTIFACT_DIR/compile.log"
PACKAGE_PLUGIN_DIR="$ARTIFACT_DIR/left4dead2/addons/sourcemod/plugins"
PACKAGE_SM_DIR="$ARTIFACT_DIR/left4dead2/addons/sourcemod"

mkdir -p "$PACKAGE_PLUGIN_DIR/anticheat" "$PACKAGE_PLUGIN_DIR/fixes" "$PACKAGE_PLUGIN_DIR/optional"
: > "$COMPILE_LOG"

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

compile_plugin() {
  local source_file="$1"
  local plugin_name
  local plugin_stem
  local plugin_dir
  local output_file

  plugin_name="$(basename "$source_file")"
  plugin_stem="${plugin_name%.sp}"
  plugin_dir="$(classify_plugin_dir "$plugin_stem")"
  output_file="$PACKAGE_PLUGIN_DIR/$plugin_dir/${plugin_stem}.smx"

  echo "Compiling $plugin_name -> plugins/$plugin_dir/${plugin_stem}.smx"
  "$SPCOMP_BIN" \
    "$source_file" \
    -i"$INCLUDE_DIR" \
    -i"$SCRIPTING_DIR" \
    -i"$SOURCEMOD_INCLUDE_DIR" \
    -o"$output_file" \
    2>&1 | tee -a "$COMPILE_LOG"
}

mapfile -t plugin_sources < <(find "$SCRIPTING_DIR" -maxdepth 1 -type f -name '*.sp' | sort)

if [[ "${#plugin_sources[@]}" -eq 0 ]]; then
  echo "No SourceMod plugin sources found in $SCRIPTING_DIR" >&2
  exit 1
fi

for source_file in "${plugin_sources[@]}"
do
  compile_plugin "$source_file"
done

mkdir -p "$PACKAGE_SM_DIR"
cp -R "$ROOT_DIR/left4dead2/addons/sourcemod/scripting" "$PACKAGE_SM_DIR/"
cp -R "$ROOT_DIR/left4dead2/addons/sourcemod/translations" "$PACKAGE_SM_DIR/"

cp "$ROOT_DIR/README.md" "$ARTIFACT_DIR/"
cp "$ROOT_DIR/plugin-package-map.json" "$ARTIFACT_DIR/"
cp -R "$ROOT_DIR/docs" "$ARTIFACT_DIR/"

echo "SourceMod artifacts generated in $ARTIFACT_DIR"
