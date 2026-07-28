#!/usr/bin/env python3
"""Repeatedly read one dataset name and measure namespace browsing."""

from __future__ import annotations

import argparse
import json
import statistics
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--path", required=True)
    parser.add_argument("--browse-dir", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--client", required=True)
    parser.add_argument("--uid-label", required=True)
    parser.add_argument("--duration", type=float, required=True)
    parser.add_argument("--interval-ms", type=float, required=True)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def percentile(values: list[float], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = min(len(ordered) - 1, int(round((len(ordered) - 1) * fraction)))
    return ordered[index]


def browse(directory: Path) -> tuple[int, float]:
    started = time.perf_counter()
    count = 0
    for entry in directory.iterdir():
        entry.stat()
        count += 1
    return count, (time.perf_counter() - started) * 1000


def main() -> int:
    args = parse_args()
    path = Path(args.path)
    browse_dir = Path(args.browse_dir)
    output = Path(args.output)
    output.parent.mkdir(parents=True, exist_ok=True)

    successes = 0
    not_found = 0
    other_errors: list[str] = []
    read_latencies_ms: list[float] = []
    browse_latencies_ms: list[float] = []
    browse_counts: list[int] = []
    started_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    deadline = time.monotonic() + args.duration
    attempt = 0

    while time.monotonic() < deadline:
        attempt += 1
        read_started = time.perf_counter()
        try:
            with path.open("rb", buffering=0) as handle:
                handle.read(65536)
            successes += 1
            read_latencies_ms.append((time.perf_counter() - read_started) * 1000)
        except FileNotFoundError:
            not_found += 1
        except OSError as error:
            other_errors.append(f"{type(error).__name__}: {error}")

        if attempt == 1 or attempt % 10 == 0:
            count, latency = browse(browse_dir)
            browse_counts.append(count)
            browse_latencies_ms.append(latency)

        time.sleep(args.interval_ms / 1000)

    result = {
        "schema_version": 1,
        "phase": args.phase,
        "client": args.client,
        "uid_label": args.uid_label,
        "path": str(path),
        "started_utc": started_utc,
        "finished_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "attempts": successes + not_found + len(other_errors),
        "successful_reads": successes,
        "file_not_found": not_found,
        "other_error_count": len(other_errors),
        "other_errors": other_errors[:10],
        "success_pct": round(
            100 * successes / max(1, successes + not_found + len(other_errors)),
            2,
        ),
        "read_latency_ms": {
            "average": round(statistics.fmean(read_latencies_ms), 4)
            if read_latencies_ms
            else 0.0,
            "p95": round(percentile(read_latencies_ms, 0.95), 4),
        },
        "browse_latency_ms": {
            "samples": len(browse_latencies_ms),
            "average": round(statistics.fmean(browse_latencies_ms), 4)
            if browse_latencies_ms
            else 0.0,
            "p95": round(percentile(browse_latencies_ms, 0.95), 4),
            "maximum_entries_seen": max(browse_counts, default=0),
        },
    }
    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"{args.phase}/{args.client}: success={successes}, "
        f"not_found={not_found}, browse_p95="
        f"{result['browse_latency_ms']['p95']:.3f}ms"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
