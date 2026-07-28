#!/usr/bin/env python3
"""Capture portable capacity and namespace counts."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lab-dir", required=True)
    parser.add_argument("--growth-dir", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    lab_dir = Path(args.lab_dir)
    growth_dir = Path(args.growth_dir)
    output = Path(args.output)

    file_count = 0
    allocated_bytes = 0
    logical_bytes = 0
    for root, _directories, files in os.walk(lab_dir):
        for filename in files:
            path = Path(root) / filename
            try:
                stat_result = path.stat()
            except FileNotFoundError:
                continue
            file_count += 1
            logical_bytes += stat_result.st_size
            allocated_bytes += stat_result.st_blocks * 512

    usage = shutil.disk_usage(lab_dir)
    result = {
        "phase": args.phase,
        "utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "lab_dir": str(lab_dir),
        "file_count": file_count,
        "growth_file_count": sum(1 for path in growth_dir.iterdir() if path.is_file()),
        "logical_bytes": logical_bytes,
        "allocated_bytes": allocated_bytes,
        "filesystem_total_bytes": usage.total,
        "filesystem_used_bytes": usage.used,
        "filesystem_free_bytes": usage.free,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"capacity/{args.phase}: files={file_count}, "
        f"allocated_bytes={allocated_bytes}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
