#!/usr/bin/env python3
"""Build Scenario 2 baseline, incident and recovery comparison."""

from __future__ import annotations

import argparse
import csv
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-dir", required=True)
    return parser.parse_args()


def load(run_dir: Path, name: str) -> dict:
    path = run_dir / name
    if not path.is_file():
        raise SystemExit(f"Missing evidence: {path}")
    return json.loads(path.read_text(encoding="utf-8"))


def main() -> int:
    args = parse_args()
    run_dir = Path(args.run_dir)
    rows = []

    for phase in ("baseline", "incident", "recovered"):
        for mapping in ("current", "stale"):
            payload = load(run_dir, f"{phase}-{mapping}.json")
            rows.append(
                {
                    "phase": phase,
                    "mapping": mapping,
                    "client": payload["client"],
                    "path": payload["path"],
                    "attempts": payload["attempts"],
                    "successful_reads": payload["successful_reads"],
                    "file_not_found": payload["file_not_found"],
                    "success_pct": payload["success_pct"],
                    "browse_p95_ms": payload["browse_latency_ms"]["p95"],
                    "entries_seen": payload["browse_latency_ms"][
                        "maximum_entries_seen"
                    ],
                }
            )

    by_key = {(row["phase"], row["mapping"]): row for row in rows}
    before = load(run_dir, "capacity-before.json")
    after = load(run_dir, "capacity-after.json")

    baseline_clean = all(
        by_key[("baseline", mapping)]["file_not_found"] == 0
        for mapping in ("current", "stale")
    )
    mixed_incident = (
        by_key[("incident", "current")]["successful_reads"] > 0
        and by_key[("incident", "current")]["file_not_found"] == 0
        and by_key[("incident", "stale")]["successful_reads"] > 0
        and by_key[("incident", "stale")]["file_not_found"] > 0
    )
    capacity_growth = (
        after["growth_file_count"] > before["growth_file_count"]
        and after["allocated_bytes"] > before["allocated_bytes"]
    )
    recovered_clean = all(
        by_key[("recovered", mapping)]["file_not_found"] == 0
        and by_key[("recovered", mapping)]["successful_reads"] > 0
        for mapping in ("current", "stale")
    )
    browse_growth = (
        by_key[("incident", "stale")]["entries_seen"]
        > by_key[("baseline", "stale")]["entries_seen"]
    )
    overall = (
        baseline_clean
        and mixed_incident
        and capacity_growth
        and recovered_clean
        and browse_growth
    )

    with (run_dir / "scenario-summary.csv").open(
        "w", newline="", encoding="utf-8"
    ) as handle:
        writer = csv.DictWriter(handle, fieldnames=rows[0].keys())
        writer.writeheader()
        writer.writerows(rows)

    mark = lambda value: "PASS" if value else "REVIEW"
    report = f"""# Scenario 2 result

Run directory: `{run_dir}`

| Phase | Mapping | Client | Success | Not found | Success % | Browse P95 ms | Entries |
|---|---|---|---:|---:|---:|---:|---:|
"""
    for row in rows:
        report += (
            f"| {row['phase']} | {row['mapping']} | {row['client']} | "
            f"{row['successful_reads']} | {row['file_not_found']} | "
            f"{float(row['success_pct']):.1f} | "
            f"{float(row['browse_p95_ms']):.3f} | {row['entries_seen']} |\n"
        )

    file_growth = after["growth_file_count"] - before["growth_file_count"]
    byte_growth = after["allocated_bytes"] - before["allocated_bytes"]
    report += f"""
## Capacity and metadata evidence

- Metadata-growth files: **{before['growth_file_count']} → {after['growth_file_count']}**
- Additional files: **{file_growth}**
- Additional allocated bytes beneath the lab: **{byte_growth}**

## Verification

- Clean baseline for both clients: **{mark(baseline_clean)}**
- Mixed incident result with intermittent stale-path failures: **{mark(mixed_incident)}**
- Capacity/metadata growth observed: **{mark(capacity_growth)}**
- Namespace entry growth observed by clients: **{mark(browse_growth)}**
- Both mappings clean after recovery: **{mark(recovered_clean)}**
- Overall scenario: **{mark(overall)}**

## Root-cause statement

The legacy publishing workflow deleted and recreated the exact `v7` shard
non-atomically while one client group continued using that stale mapping. Reads
that landed inside the missing-name window returned `FileNotFoundError`; reads
through the canonical `current` mapping continued to succeed. Metadata and
capacity growth increased namespace work and browse latency, but did not explain
the client-specific missing name. Preserving the legacy state, stopping the
publisher and mapping `v7` to the canonical dataset restored both clients.
"""
    (run_dir / "scenario-summary.md").write_text(report, encoding="utf-8")
    print(
        f"overall={mark(overall)} stale_not_found="
        f"{by_key[('incident', 'stale')]['file_not_found']} "
        f"growth_files={file_growth}"
    )
    return 0 if overall else 2


if __name__ == "__main__":
    raise SystemExit(main())
