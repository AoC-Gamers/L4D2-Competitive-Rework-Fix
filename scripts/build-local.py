#!/usr/bin/env python3

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def classify_plugin(plugin_stem: str, package_map: dict) -> str:
    if plugin_stem in package_map.get("anticheat", []):
        return "anticheat"
    if plugin_stem in package_map.get("fixes", []):
        return "fixes"
    return "optional"


def run_spcomp(spcomp: Path, source_file: Path, include_dirs: list[Path], output_file: Path, compile_log: Path) -> None:
    cmd = [str(spcomp), str(source_file)]
    for include_dir in include_dirs:
        cmd.append(f"-i{include_dir}")
    cmd.append(f"-o{output_file}")

    print(f"Compiling {source_file.name} -> plugins/{output_file.parent.name}/{output_file.name}", flush=True)
    result = subprocess.run(cmd, capture_output=True, text=True, check=False)

    if result.stdout:
        print(result.stdout, end="")
    if result.stderr:
        print(result.stderr, end="", file=sys.stderr)

    with compile_log.open("a", encoding="utf-8", newline="") as fh:
        if result.stdout:
            fh.write(result.stdout)
        if result.stderr:
            fh.write(result.stderr)

    if result.returncode != 0:
        raise RuntimeError(f"spcomp failed for {source_file.name}")

    if not output_file.exists():
        raise RuntimeError(f"Expected output file was not generated: {output_file}")


def main() -> int:
    parser = argparse.ArgumentParser(description="Compile SourceMod plugins into a local build directory.")
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--spcomp", required=True, help="Path to spcomp executable")
    parser.add_argument("--output-root", default="build", help="Output directory relative to repo root")
    parser.add_argument("--compile-log", required=True, help="Compile log path relative to repo root")
    parser.add_argument("--workspace", default="", help="Optional temporary workspace directory")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    spcomp = Path(args.spcomp).resolve()
    output_root = (root / args.output_root).resolve()
    compile_log = (root / args.compile_log).resolve()
    workspace = Path(args.workspace).resolve() if args.workspace else None

    if not spcomp.exists():
        raise FileNotFoundError(f"spcomp not found: {spcomp}")

    source_mod_include_dir = spcomp.parent / "include"
    if not source_mod_include_dir.exists():
        raise FileNotFoundError(f"SourceMod include dir not found: {source_mod_include_dir}")

    package_map_path = root / "plugin-package-map.json"
    if not package_map_path.exists():
        raise FileNotFoundError(f"plugin-package-map.json not found: {package_map_path}")

    with package_map_path.open("r", encoding="utf-8") as fh:
        package_map = json.load(fh)

    source_root = root / "addons" / "sourcemod"
    scripting_dir = source_root / "scripting"
    include_dir = scripting_dir / "include"
    translations_dir = source_root / "translations"

    if workspace is not None:
        if workspace.exists():
            shutil.rmtree(workspace)
        workspace.mkdir(parents=True, exist_ok=True)
        workspace_source_root = workspace / "addons" / "sourcemod"
        shutil.copytree(source_root, workspace_source_root, dirs_exist_ok=True)
        workspace_spcomp_dir = workspace / "spcomp"
        workspace_spcomp_dir.mkdir(parents=True, exist_ok=True)
        workspace_spcomp = workspace_spcomp_dir / spcomp.name
        shutil.copy2(spcomp, workspace_spcomp)
        workspace_spcomp.chmod(workspace_spcomp.stat().st_mode | 0o111)
        shutil.copytree(source_mod_include_dir, workspace_spcomp_dir / "include", dirs_exist_ok=True)
        source_root = workspace_source_root
        scripting_dir = source_root / "scripting"
        include_dir = scripting_dir / "include"
        translations_dir = source_root / "translations"
        spcomp = workspace_spcomp
        source_mod_include_dir = workspace_spcomp_dir / "include"

    artifact_root = output_root / "addons" / "sourcemod"
    plugins_root = artifact_root / "plugins"

    if output_root.exists():
        shutil.rmtree(output_root)

    compile_log.parent.mkdir(parents=True, exist_ok=True)
    compile_log.write_text("", encoding="utf-8")

    for bucket in ("anticheat", "fixes", "optional"):
        (plugins_root / bucket).mkdir(parents=True, exist_ok=True)

    plugin_sources = sorted(scripting_dir.glob("*.sp"))
    if not plugin_sources:
        raise RuntimeError(f"No plugin sources found in {scripting_dir}")

    include_dirs = [include_dir, scripting_dir, source_mod_include_dir]

    for source_file in plugin_sources:
        plugin_stem = source_file.stem
        bucket = classify_plugin(plugin_stem, package_map)
        output_file = plugins_root / bucket / f"{plugin_stem}.smx"
        run_spcomp(spcomp, source_file, include_dirs, output_file, compile_log)

    shutil.copytree(scripting_dir, artifact_root / "scripting")
    shutil.copytree(translations_dir, artifact_root / "translations")

    if workspace is not None and workspace.exists():
        shutil.rmtree(workspace)

    print()
    print(f"Build local completed in: {output_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
