#!/usr/bin/env python3

import argparse
import platform as py_platform
import shutil
import sys
import tarfile
import urllib.request
import urllib.error
import zipfile
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser(description="Download and extract a SourceMod compiler package.")
    parser.add_argument("--root", default=".", help="Repository root")
    parser.add_argument("--platform", choices=("windows", "linux"), help="SourceMod package platform")
    parser.add_argument("--version", default="1.12", help="SourceMod version")
    args = parser.parse_args()

    root = Path(args.root).resolve()
    deps_dir = root / "deps"
    work_dir = deps_dir / f"sourcemod-{args.platform}"
    platform = args.platform or detect_platform()
    archive_suffix = "zip" if platform == "windows" else "tar.gz"
    archive_path = deps_dir / f"sourcemod-{platform}.{archive_suffix}"
    url = f"https://www.sourcemod.net/latest.php?os={platform}&version={args.version}"

    if work_dir.exists():
        shutil.rmtree(work_dir)
    deps_dir.mkdir(parents=True, exist_ok=True)

    print(f"Downloading SourceMod for {platform} from: {url}")
    request = urllib.request.Request(
        url,
        headers={
            "User-Agent": "Mozilla/5.0",
            "Accept": "*/*",
        },
    )
    try:
        with urllib.request.urlopen(request) as response, archive_path.open("wb") as fh:
            shutil.copyfileobj(response, fh)
    except urllib.error.HTTPError as exc:
        raise RuntimeError(f"Failed to download SourceMod package: HTTP {exc.code}") from exc

    if platform == "windows":
        with zipfile.ZipFile(archive_path, "r") as zf:
            zf.extractall(work_dir)
    else:
        work_dir.mkdir(parents=True, exist_ok=True)
        with tarfile.open(archive_path, "r:gz") as tf:
            tf.extractall(work_dir)

    print(f"Dependencies ready in: {work_dir}")
    return 0


def detect_platform() -> str:
    system = py_platform.system().lower()
    if system.startswith("win"):
        return "windows"
    if system == "linux":
        return "linux"
    raise RuntimeError(f"Unsupported platform: {py_platform.system()}")


if __name__ == "__main__":
    raise SystemExit(main())
