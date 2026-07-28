# Scenario 1 — AI Training Performance Degradation

Trainer-led Ubuntu 24.04 lab for this incident:

- training duration changes from approximately 3 hours to 6 hours;
- GPU utilization falls from approximately 95% to 45%;
- dataset loading becomes slow;
- no application-code change occurred.

The project runs on an isolated Ubuntu VM with or without an NVIDIA GPU. It
performs real dataset-file reads and starts a real competing small-block `fio`
workload. For repeatable classroom results on different hardware, it also adds
a clearly recorded delay to the degraded data-loader path.

When no NVIDIA GPU is installed, the reported `simulated_gpu_util_pct` is a
teaching metric calculated as:

```text
compute-busy time / (compute-busy time + dataset-wait time) × 100
```

It demonstrates GPU starvation; it is not a physical GPU measurement. If
`nvidia-smi` is available, the scripts capture real GPU telemetry separately.

## Tested platform

- Ubuntu 24.04 LTS
- x86_64/AMD64 compatible
- Bash 5, Python 3.12, fio 3.x
- A physical GPU is optional

The screenshot system (`Ubuntu 24.04`, `x86_64`, kernel
`7.0.0-28-generic`) is compatible. The project does not depend on a specific
kernel patch level.

## Safety

Use only a disposable training directory. Never use a production dataset.
Preparation requires `CONFIRM_DISPOSABLE_LAB=YES` and refuses `/`, `/home`,
`/root`, and shallow paths. All generated files remain under `LAB_DIR`.

The competing workload uses its own disposable file. It never writes to the
dataset file.

## Quick start on Ubuntu

```bash
unzip VAST_AI_Training_Degradation_Ubuntu.zip
cd scenario1-ai-training-performance

cp config.env.example config.env
nano config.env

./scripts/00-install-tools.sh
./run-demo.sh
```

The default configuration uses:

```text
/var/tmp/vast-ai-training-lab
```

For a mounted VAST training View, change only `LAB_DIR` to a new empty
disposable directory on that mount.

## Participant sequence

The one-command demo runs these stages:

1. Preflight: identify OS, architecture, storage path and optional GPU.
2. Prepare: create disposable dataset and contention files.
3. Baseline: record normal data loading and simulated GPU utilization.
4. Degraded: start small-block contention and inject repeatable loader wait.
5. Recovery: stop the fault and rerun the original workload.
6. Report: compare baseline, degraded and recovered evidence.

Individual commands:

```bash
./scripts/01-preflight.sh
./scripts/02-prepare-lab.sh
./scripts/03-run-baseline.sh
./scripts/04-run-degraded.sh
./scripts/05-run-recovery.sh
./scripts/06-build-report.sh
```

Results are written under:

```text
$LAB_DIR/artifacts/<run-id>/
```

Open `scenario-summary.md` after the run.

## Expected result

With the supplied defaults:

- baseline simulated GPU utilization is normally around 95%;
- degraded utilization is normally between 35% and 55%;
- extrapolated training duration approaches 6 hours;
- recovery returns close to the baseline.

Exact values vary because the scripts also measure real dataset-read time.

## Real VAST delivery

For an instructor demonstration on VAST:

1. Mount a dedicated training View on Ubuntu.
2. Set `LAB_DIR` to a new subdirectory on that mount.
3. Run the preflight and confirm the filesystem/mount evidence.
4. Correlate the timestamps with VMS bandwidth, IOPS, latency, queueing, alarms
   and events.
5. Keep the delay injection enabled for repeatability, but explain that it
   emulates additional data-delivery wait. The competing `fio` process is the
   observable shared-path contention signal.

## Cleanup

```bash
./cleanup.sh
```

Cleanup shows the exact directory and requires interactive confirmation unless
`CONFIRM_CLEANUP=YES` is supplied.
