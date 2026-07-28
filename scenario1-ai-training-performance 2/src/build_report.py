#!/usr/bin/env python3
"""Build a concise baseline/degraded/recovery report."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    parser.add_argument("--baseline-hours", type=float, default=3.0)
    return parser.parse_args()


def load_phase(run_dir: Path, name: str) -> dict:
    path = run_dir / f"{name}.json"
    if not path.is_file():
        raise SystemExit(f"Missing phase evidence: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    args = parse_args()
    run_dir = Path(args.run_dir)
    phases = {
        name: load_phase(run_dir, name)
        for name in ("baseline", "degraded", "recovered")
    }

    rows = []
    for name, payload in phases.items():
        measurement = payload["measurements"]
        rows.append(
            {
                "phase": name,
                "elapsed_seconds": measurement["wall_seconds"],
                "dataset_mib_s": measurement["dataset_throughput_mib_s"],
                "simulated_gpu_util_pct": measurement["simulated_gpu_util_pct"],
                "actual_read_seconds": measurement["actual_file_read_seconds"],
                "injected_wait_seconds": measurement[
                    "injected_loader_wait_seconds"
                ],
            }
        )

    baseline_elapsed = float(rows[0]["elapsed_seconds"])
    degraded_elapsed = float(rows[1]["elapsed_seconds"])
    recovered_elapsed = float(rows[2]["elapsed_seconds"])
    slowdown = degraded_elapsed / baseline_elapsed
    projected_degraded_hours = args.baseline_hours * slowdown
    recovery_delta = abs(recovered_elapsed - baseline_elapsed) / baseline_elapsed

    degradation_pass = slowdown >= 1.7
    gpu_pass = (
        float(rows[0]["simulated_gpu_util_pct"]) >= 80
        and float(rows[1]["simulated_gpu_util_pct"]) <= 60
    )
    recovery_pass = recovery_delta <= 0.25
    overall = degradation_pass and gpu_pass and recovery_pass

    csv_path = run_dir / "scenario-summary.csv"
    with csv_path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    def result_mark(value: bool) -> str:
        return "PASS" if value else "REVIEW"

    report = f"""# Scenario 1 result

Run directory: `{run_dir}`

| Phase | Elapsed (s) | Dataset MiB/s | Simulated GPU % | Actual read (s) | Injected wait (s) |
|---|---:|---:|---:|---:|---:|
"""
    for row in rows:
        report += (
            f"| {row['phase']} | {float(row['elapsed_seconds']):.2f} | "
            f"{float(row['dataset_mib_s']):.1f} | "
            f"{float(row['simulated_gpu_util_pct']):.1f} | "
            f"{float(row['actual_read_seconds']):.3f} | "
            f"{float(row['injected_wait_seconds']):.3f} |\n"
        )

    report += f"""
## Business interpretation

- Measured slowdown: **{slowdown:.2f}×**
- If the baseline job takes **{args.baseline_hours:.1f} hours**, the degraded
  projection is **{projected_degraded_hours:.1f} hours**.
- The degraded data-loader wait starves the accelerator, so low GPU utilization
  is a downstream symptom rather than proof of a GPU failure.

## Verification

- Degradation at least 1.7×: **{result_mark(degradation_pass)}**
- Baseline/degraded GPU teaching signal: **{result_mark(gpu_pass)}**
- Recovery within 25% of baseline: **{result_mark(recovery_pass)}**
- Overall scenario: **{result_mark(overall)}**

## Root-cause teaching chain

1. A competing small-block workload appears on the shared storage path.
2. Dataset-delivery wait increases.
3. Training consumers wait for batches.
4. GPU utilization falls.
5. Removing the controlled fault and repeating the same workload proves recovery.

`simulated_gpu_util_pct` is explicitly a teaching metric. If an NVIDIA GPU was
present, use the phase `*-nvidia-smi.csv` files as the physical GPU evidence.
"""
    (run_dir / "scenario-summary.md").write_text(report, encoding="utf-8")
    print(
        f"overall={result_mark(overall)} slowdown={slowdown:.2f} "
        f"projected_hours={projected_degraded_hours:.1f}"
    )
    return 0 if overall else 2


if __name__ == "__main__":
    raise SystemExit(main())
