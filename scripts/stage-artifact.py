#!/usr/bin/env python3

import shutil
import sys
from pathlib import Path


def copy_if_exists(source: Path, destination: Path) -> None:
    if not source.exists():
        return
    if source.is_dir():
        shutil.copytree(source, destination, dirs_exist_ok=True)
    else:
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)


def main() -> int:
    if len(sys.argv) not in (4, 5):
        raise SystemExit("Usage: stage-artifact.py <root_dir> <build_dir> <compile_log> [output_dir]")

    root_dir = Path(sys.argv[1]).resolve()
    build_dir = Path(sys.argv[2]).resolve()
    compile_log = Path(sys.argv[3]).resolve()
    output_dir = Path(sys.argv[4]).resolve() if len(sys.argv) == 5 else root_dir / "dist" / "sourcemod" / "artifact"
    addons_dir = build_dir / "addons"

    if not addons_dir.exists():
        raise FileNotFoundError(f"Expected build output not found at {addons_dir}")

    if output_dir.exists():
        shutil.rmtree(output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)

    copy_if_exists(addons_dir, output_dir / "addons")
    plugins_dir = output_dir / "addons" / "sourcemod" / "plugins"
    for bucket in ("anticheat", "fixes", "optional"):
        (plugins_dir / bucket).mkdir(parents=True, exist_ok=True)
    copy_if_exists(root_dir / "README.md", output_dir / "README.md")
    copy_if_exists(root_dir / "plugin-package-map.json", output_dir / "plugin-package-map.json")
    copy_if_exists(root_dir / "docs", output_dir / "docs")

    compile_log_dest = output_dir / "compile.log"
    if compile_log.is_file():
        shutil.copy2(compile_log, compile_log_dest)
    else:
        compile_log_dest.write_text("", encoding="utf-8")

    print(f"SourceMod artifacts generated in {output_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
