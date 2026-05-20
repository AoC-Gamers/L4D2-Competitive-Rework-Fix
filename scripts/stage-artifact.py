#!/usr/bin/env python3

import os
import shutil
import sys


def main() -> int:
    if len(sys.argv) != 4:
        print("usage: stage-artifact.py <root_dir> <build_dir> <compile_log>", file=sys.stderr)
        return 1

    root_dir, build_dir, compile_log = sys.argv[1:4]
    artifact_dir = os.path.join(root_dir, "dist", "sourcemod", "artifact")
    addons_dir = os.path.join(build_dir, "addons")

    if not os.path.isdir(addons_dir):
        print(f"Expected build output not found at {addons_dir}", file=sys.stderr)
        return 1

    dist_dir = os.path.dirname(artifact_dir)
    if os.path.isdir(dist_dir):
        shutil.rmtree(dist_dir)
    os.makedirs(artifact_dir, exist_ok=True)

    shutil.copytree(addons_dir, os.path.join(artifact_dir, "addons"))
    shutil.copy2(os.path.join(root_dir, "README.md"), os.path.join(artifact_dir, "README.md"))
    shutil.copy2(os.path.join(root_dir, "plugin-package-map.json"), os.path.join(artifact_dir, "plugin-package-map.json"))
    shutil.copytree(os.path.join(root_dir, "docs"), os.path.join(artifact_dir, "docs"))

    compile_log_dest = os.path.join(artifact_dir, "compile.log")
    if os.path.isfile(compile_log):
        shutil.copy2(compile_log, compile_log_dest)
    else:
        open(compile_log_dest, "w", encoding="utf-8").close()

    print(f"SourceMod artifacts generated in {artifact_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
