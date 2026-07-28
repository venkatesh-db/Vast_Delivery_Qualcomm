#!/usr/bin/env python3
"""Small, dependency-free data-loader and GPU-starvation teaching simulator."""

from __future__ import annotations

import argparse
import json
import os
import platform
import time
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dataset", required=True)
    parser.add_argument("--phase", required=True)
    parser.add_argument("--batches", type=int, required=True)
    parser.add_argument("--batch-bytes", type=int, required=True)
    parser.add_argument("--compute-ms", type=float, required=True)
    parser.add_argument("--loader-delay-ms", type=float, required=True)
    parser.add_argument("--drop-cache-hint", type=int, choices=(0, 1), default=1)
    parser.add_argument("--output", required=True)
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    dataset = Path(args.dataset)
    output = Path(args.output)

    if not dataset.is_file():
        raise SystemExit(f"Dataset is missing: {dataset}")
    if args.batches <= 0 or args.batch_bytes <= 0:
        raise SystemExit("Batch count and batch size must be positive.")

    output.parent.mkdir(parents=True, exist_ok=True)
    dataset_bytes = dataset.stat().st_size
    if dataset_bytes < args.batch_bytes:
        raise SystemExit("Dataset must be at least as large as one batch.")

    actual_read_seconds = 0.0
    injected_wait_seconds = 0.0
    compute_seconds = 0.0
    total_bytes = 0
    started_utc = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    wall_start = time.perf_counter()

    with dataset.open("rb", buffering=0) as handle:
        if (
            args.drop_cache_hint
            and hasattr(os, "posix_fadvise")
            and hasattr(os, "POSIX_FADV_DONTNEED")
        ):
            try:
                os.posix_fadvise(
                    handle.fileno(), 0, 0, os.POSIX_FADV_DONTNEED
                )
            except OSError:
                pass

        for _ in range(args.batches):
            read_started = time.perf_counter()
            block = handle.read(args.batch_bytes)
            if len(block) < args.batch_bytes:
                handle.seek(0)
                remainder = args.batch_bytes - len(block)
                block += handle.read(remainder)
            actual_read_seconds += time.perf_counter() - read_started
            total_bytes += len(block)

            if args.loader_delay_ms:
                wait_started = time.perf_counter()
                time.sleep(args.loader_delay_ms / 1000.0)
                injected_wait_seconds += time.perf_counter() - wait_started

            compute_started = time.perf_counter()
            # Sleeping represents accelerator-busy time without requiring a GPU.
            time.sleep(args.compute_ms / 1000.0)
            compute_seconds += time.perf_counter() - compute_started

    wall_seconds = time.perf_counter() - wall_start
    data_wait_seconds = actual_read_seconds + injected_wait_seconds
    modeled_seconds = data_wait_seconds + compute_seconds
    simulated_gpu_util = (
        100.0 * compute_seconds / modeled_seconds if modeled_seconds else 0.0
    )
    throughput_mib_s = (
        total_bytes / 1024 / 1024 / wall_seconds if wall_seconds else 0.0
    )

    result = {
        "schema_version": 1,
        "phase": args.phase,
        "started_utc": started_utc,
        "finished_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "host": {
            "platform": platform.platform(),
            "machine": platform.machine(),
            "python": platform.python_version(),
        },
        "configuration": {
            "dataset": str(dataset),
            "dataset_bytes": dataset_bytes,
            "batches": args.batches,
            "batch_bytes": args.batch_bytes,
            "compute_ms_per_batch": args.compute_ms,
            "injected_loader_delay_ms_per_batch": args.loader_delay_ms,
        },
        "measurements": {
            "wall_seconds": round(wall_seconds, 6),
            "actual_file_read_seconds": round(actual_read_seconds, 6),
            "injected_loader_wait_seconds": round(injected_wait_seconds, 6),
            "total_data_wait_seconds": round(data_wait_seconds, 6),
            "compute_busy_seconds": round(compute_seconds, 6),
            "bytes_read": total_bytes,
            "dataset_throughput_mib_s": round(throughput_mib_s, 3),
            "simulated_gpu_util_pct": round(simulated_gpu_util, 2),
        },
        "metric_notice": (
            "simulated_gpu_util_pct is a teaching metric, not a physical GPU "
            "measurement. See phase nvidia-smi evidence when available."
        ),
    }

    output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(
        f"{args.phase}: elapsed={wall_seconds:.2f}s, "
        f"dataset={throughput_mib_s:.1f} MiB/s, "
        f"simulated GPU={simulated_gpu_util:.1f}%"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
