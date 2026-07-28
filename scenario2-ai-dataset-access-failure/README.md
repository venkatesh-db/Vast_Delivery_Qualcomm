# Scenario 2 — AI Dataset Access Failure

Trainer-led Ubuntu 24.04 lab for this incident:

- multiple AI teams randomly fail while accessing one shared dataset;
- clients see intermittent `file not found` errors;
- dataset browsing becomes slower;
- some jobs succeed while others fail;
- storage utilization is increasing.

The lab reproduces the course's intended causal chain:

```text
non-atomic legacy-path publishing + stale client path mapping
→ intermittent missing names for one client group
```

It separately generates metadata/capacity growth, demonstrating why correlated
pressure can slow browsing without being the direct cause of every missing-file
error.

## Tested platform

- Ubuntu 24.04 LTS
- x86_64/AMD64 compatible
- Bash 5 and Python 3.12
- No GPU required

The screenshot system (`Ubuntu 24.04`, `x86_64`, kernel
`7.0.0-28-generic`) is compatible. No script depends on a specific kernel
patch level.

## What is real and what is simulated

The project performs real filesystem operations:

- reads the same shard repeatedly from two different path mappings;
- atomically replaces the canonical shard;
- non-atomically deletes and recreates the stale legacy shard;
- creates real metadata files and measures namespace browsing;
- records UTC event, capacity and client evidence;
- repairs the stale mapping and repeats the same reads.

Client names and UIDs are scenario labels. The project does not create Linux
users or claim to reproduce a VAST ACL. On a mounted VAST training View, the
same operations travel over the mounted protocol.

## Safety

Use only a disposable training directory. Preparation requires
`CONFIRM_DISPOSABLE_LAB=YES`, and destructive operations require the sentinel
created by the preparation script. The project refuses `/`, `/home`, `/root`
and shallow system paths.

Never set `LAB_DIR` to a real dataset.

## Quick start on Ubuntu

```bash
unzip VAST_AI_Dataset_Access_Failure_Ubuntu.zip
cd scenario2-ai-dataset-access-failure

cp config.env.example config.env
nano config.env

./scripts/00-install-tools.sh
./run-demo.sh
```

The default run finishes in approximately 15–25 seconds after packages are
installed.

## Individual stages

```bash
./scripts/01-preflight.sh
./scripts/02-prepare-lab.sh
./scripts/03-run-baseline.sh
./scripts/04-run-incident.sh
./scripts/05-recover-and-retest.sh
./scripts/06-build-report.sh
```

Evidence is written to:

```text
$LAB_DIR/artifacts/<run-id>/
```

Open `scenario-summary.md` for the participant-facing result.

## Expected evidence

- Both clients succeed during baseline.
- The canonical `current` client continues to succeed during the incident.
- The stale `v7` client records both successful reads and `FileNotFoundError`.
- Metadata file count and used bytes increase.
- Browse latency rises as the namespace grows.
- After the stale path is corrected, both clients complete without missing-file
  errors.

Exact counts and timings vary by VM and filesystem.

## Using a VAST training View

Set `LAB_DIR` to a new empty subdirectory beneath the mounted training View.
Rehearse before class and correlate the generated UTC timestamps with VMS:

- protocol operations and errors;
- metadata and capacity behavior;
- bandwidth, IOPS and latency;
- alarms and events.

This lab does not emulate VAST internals or establish performance limits.

## Cleanup

```bash
./cleanup.sh
```

Cleanup prints the exact path and requires `DELETE`, unless
`CONFIRM_CLEANUP=YES` is supplied.
