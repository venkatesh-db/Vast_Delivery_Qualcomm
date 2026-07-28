#!/usr/bin/env python3
"""Create the disposable namespace used by Scenario 2."""

from __future__ import annotations

import argparse
import os
import shutil
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lab-dir", required=True)
    parser.add_argument("--shard-size", type=int, required=True)
    parser.add_argument("--initial-metadata-files", type=int, required=True)
    parser.add_argument("--metadata-file-bytes", type=int, required=True)
    return parser.parse_args()


def write_sized_file(path: Path, size: int, marker: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    block = (marker + b"\n").ljust(min(size, 65536), b"x")
    remaining = size
    with path.open("wb") as handle:
        while remaining:
            chunk = block[: min(len(block), remaining)]
            handle.write(chunk)
            remaining -= len(chunk)
        handle.flush()
        os.fsync(handle.fileno())


def main() -> int:
    args = parse_args()
    lab_dir = Path(args.lab_dir)
    datasets = lab_dir / "datasets"
    releases = datasets / "releases"
    release_v8 = releases / "v8"
    legacy_v7 = datasets / "v7"
    growth = datasets / "metadata-growth"
    current = datasets / "current"

    # The shell wrapper verifies the lab sentinel before a repeat run. Reset
    # only the generated dataset subtree; retain earlier evidence in artifacts.
    if datasets.exists():
        shutil.rmtree(datasets)

    for directory in (release_v8, legacy_v7, growth):
        directory.mkdir(parents=True, exist_ok=True)

    if current.is_symlink() or current.exists():
        if current.is_dir() and not current.is_symlink():
            shutil.rmtree(current)
        else:
            current.unlink()
    current.symlink_to(Path("releases") / "v8", target_is_directory=True)

    write_sized_file(
        release_v8 / "shard-042.bin", args.shard_size, b"canonical-v8"
    )
    write_sized_file(
        legacy_v7 / "shard-042.bin", args.shard_size, b"legacy-v7"
    )

    payload = b"m" * args.metadata_file_bytes
    for index in range(args.initial_metadata_files):
        (growth / f"base-{index:06d}.meta").write_bytes(payload)

    print(f"Prepared dataset namespace beneath {datasets}")
    print(f"Initial metadata files: {args.initial_metadata_files}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
