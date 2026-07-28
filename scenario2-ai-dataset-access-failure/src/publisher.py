#!/usr/bin/env python3
"""Generate atomic canonical updates and unsafe legacy delete/recreate events."""

from __future__ import annotations

import argparse
import json
import os
import signal
import time
from pathlib import Path


running = True


def request_stop(_signum: int, _frame: object) -> None:
    global running
    running = False


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--current-shard", required=True)
    parser.add_argument("--legacy-shard", required=True)
    parser.add_argument("--growth-dir", required=True)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--publish-interval-ms", type=float, required=True)
    parser.add_argument("--legacy-delete-gap-ms", type=float, required=True)
    parser.add_argument("--growth-files-per-cycle", type=int, required=True)
    parser.add_argument("--metadata-file-bytes", type=int, required=True)
    parser.add_argument("--event-log", required=True)
    return parser.parse_args()


def utc_now() -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime()) + (
        f".{int(time.time_ns() % 1_000_000_000 / 1_000_000):03d}Z"
    )


def main() -> int:
    args = parse_args()
    current = Path(args.current_shard)
    legacy = Path(args.legacy_shard)
    growth = Path(args.growth_dir)
    event_log = Path(args.event_log)
    event_log.parent.mkdir(parents=True, exist_ok=True)
    growth.mkdir(parents=True, exist_ok=True)

    shard_size = max(current.stat().st_size, legacy.stat().st_size)
    metadata_payload = b"g" * args.metadata_file_bytes
    deadline = time.monotonic() + args.duration
    iteration = 0

    signal.signal(signal.SIGTERM, request_stop)
    signal.signal(signal.SIGINT, request_stop)

    def log_event(operation: str, path: Path, detail: str = "") -> None:
        record = {
            "utc": utc_now(),
            "iteration": iteration,
            "operation": operation,
            "path": str(path),
            "detail": detail,
        }
        with event_log.open("a", encoding="utf-8") as handle:
            handle.write(json.dumps(record) + "\n")

    try:
        while running and time.monotonic() < deadline:
            iteration += 1
            marker = f"publish-{iteration}".encode()
            payload = (marker + b"\n").ljust(shard_size, b"d")

            temporary = current.with_name(f".shard-042.tmp-{os.getpid()}")
            temporary.write_bytes(payload)
            os.replace(temporary, current)
            log_event("atomic_replace", current, "canonical mapping remains valid")

            try:
                legacy.unlink()
                log_event("delete", legacy, "non-atomic legacy publish window begins")
            except FileNotFoundError:
                log_event("delete_missing", legacy)

            time.sleep(args.legacy_delete_gap_ms / 1000)
            legacy.write_bytes(payload)
            log_event("create", legacy, "legacy publish window ends")

            base_index = iteration * args.growth_files_per_cycle
            for offset in range(args.growth_files_per_cycle):
                target = growth / f"growth-{base_index + offset:08d}.meta"
                target.write_bytes(metadata_payload)
            log_event(
                "capacity_growth",
                growth,
                f"added={args.growth_files_per_cycle}",
            )
            time.sleep(args.publish_interval_ms / 1000)
    finally:
        if not legacy.exists():
            legacy.write_bytes(b"recovered-on-publisher-exit\n".ljust(shard_size, b"d"))
            log_event("restore_on_exit", legacy)
        log_event("publisher_stop", legacy, f"cycles={iteration}")

    print(f"publisher cycles={iteration}, event_log={event_log}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
