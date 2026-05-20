#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="${SOURCEMOD_ARTIFACT_DIR:-$ROOT_DIR/dist/sourcemod/artifact}"
PACKAGE_MAP_PATH="$ROOT_DIR/plugin-package-map.json"

if [[ ! -d "$ARTIFACT_DIR" ]]; then
  echo "SourceMod artifact directory not found at $ARTIFACT_DIR" >&2
  exit 1
fi

python3 - "$ROOT_DIR" "$ARTIFACT_DIR" "$PACKAGE_MAP_PATH" <<'PY'
import json
import os
import sys

root_dir, artifact_dir, package_map_path = sys.argv[1], sys.argv[2], sys.argv[3]

with open(package_map_path, "r", encoding="utf-8") as fh:
    package_map = json.load(fh)

source_scripting_dir = os.path.join(root_dir, "left4dead2", "addons", "sourcemod", "scripting")
source_translations_dir = os.path.join(root_dir, "left4dead2", "addons", "sourcemod", "translations")
artifact_plugins_dir = os.path.join(artifact_dir, "left4dead2", "addons", "sourcemod", "plugins")
artifact_scripting_dir = os.path.join(artifact_dir, "left4dead2", "addons", "sourcemod", "scripting")
artifact_translations_dir = os.path.join(artifact_dir, "left4dead2", "addons", "sourcemod", "translations")

expected_plugins = sorted(
    os.path.splitext(entry)[0]
    for entry in os.listdir(source_scripting_dir)
    if entry.endswith(".sp") and os.path.isfile(os.path.join(source_scripting_dir, entry))
)

if not expected_plugins:
    raise SystemExit("No plugin sources found to validate")

classified_expected = {}
for plugin in expected_plugins:
    if plugin in package_map.get("anticheat", []):
        classified_expected[plugin] = "anticheat"
    elif plugin in package_map.get("fixes", []):
        classified_expected[plugin] = "fixes"
    else:
        classified_expected[plugin] = "optional"

for plugin, folder in classified_expected.items():
    compiled_path = os.path.join(artifact_plugins_dir, folder, f"{plugin}.smx")
    if not os.path.isfile(compiled_path):
        raise SystemExit(f"Missing compiled plugin: {compiled_path}")

for folder in ("anticheat", "fixes", "optional"):
    folder_path = os.path.join(artifact_plugins_dir, folder)
    if not os.path.isdir(folder_path):
        raise SystemExit(f"Missing plugin folder: {folder_path}")

for folder in ("anticheat", "fixes", "optional"):
    folder_path = os.path.join(artifact_plugins_dir, folder)
    for entry in os.listdir(folder_path):
        if not entry.endswith(".smx"):
            raise SystemExit(f"Unexpected non-plugin entry in {folder}: {entry}")
        plugin = os.path.splitext(entry)[0]
        expected_folder = classified_expected.get(plugin)
        if expected_folder != folder:
            raise SystemExit(f"Plugin {plugin} packaged in {folder}, expected {expected_folder}")

source_sp_entries = sorted(entry for entry in os.listdir(source_scripting_dir) if entry.endswith(".sp"))
artifact_sp_entries = sorted(entry for entry in os.listdir(artifact_scripting_dir) if entry.endswith(".sp"))
if source_sp_entries != artifact_sp_entries:
    raise SystemExit(f"Scripting source mismatch. Expected {source_sp_entries}, got {artifact_sp_entries}")

for name in ("include", "readyup", "l4d2_skill_detect"):
    expected_path = os.path.join(source_scripting_dir, name)
    artifact_path = os.path.join(artifact_scripting_dir, name)
    if os.path.isdir(expected_path) and not os.path.isdir(artifact_path):
        raise SystemExit(f"Missing scripting directory in artifact: {name}")

for root, _, files in os.walk(source_translations_dir):
    for file_name in files:
        source_path = os.path.join(root, file_name)
        rel_path = os.path.relpath(source_path, source_translations_dir)
        artifact_path = os.path.join(artifact_translations_dir, rel_path)
        if not os.path.isfile(artifact_path):
            raise SystemExit(f"Missing translation file: {artifact_path}")

for rel_path in ("README.md", "plugin-package-map.json", "docs", "compile.log"):
    artifact_path = os.path.join(artifact_dir, rel_path)
    if not os.path.exists(artifact_path):
        raise SystemExit(f"Missing packaged project asset: {artifact_path}")

print("ARTIFACT_VALIDATION_OK")
PY
