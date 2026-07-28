# Trainer guide

## Learning objective

Participants must prove this causal chain:

```text
shared-path contention → increased dataset wait → starved training consumers
→ lower GPU utilization → longer training duration
```

Low GPU utilization is an impact signal. It is not sufficient evidence of a
GPU fault.

## Before class

```bash
cp config.env.example config.env
nano config.env
./scripts/00-install-tools.sh
./scripts/01-preflight.sh
```

If using VAST, set `LAB_DIR` to a new disposable subdirectory on the mounted
training View. Never use a real dataset.

## Fast instructor demonstration

```bash
./run-demo.sh
```

Show participants:

1. `baseline.json`
2. `competing-fio.json`
3. `degraded.json`
4. `recovered.json`
5. `scenario-summary.md`
6. the aligned `vmstat`, `iostat`, `sar` and optional `nvidia-smi` evidence

## Evidence-wave delivery

### Wave 0 — customer report

- Job duration: 3 hours → 6 hours
- GPU utilization: 95% → 45%
- Dataset loading is slow
- No application-code change

Ask for ranked hypotheses. Do not reveal the injected fault.

### Wave 1 — application

Reveal baseline and degraded phase JSON files. Ask whether lower GPU use is a
cause or consequence.

### Wave 2 — client

Reveal `vmstat` and `iostat`. Ask participants to rule client CPU or memory
pressure in or out.

### Wave 3 — workload and storage

Reveal `competing-fio.json` and VMS metrics for the same UTC interval. Expected
finding: concurrent small-block I/O aligns with increased loader wait.

### Wave 4 — recovery

Run:

```bash
./scripts/05-run-recovery.sh
./scripts/06-build-report.sh
```

Success requires the same training workload to return close to baseline.

## Debrief

- Root cause in this lab: controlled competing small-block workload plus a
  repeatable data-loader delay used to make the symptom visible on any VM.
- Mechanism: increased data wait starves training consumers.
- Downstream symptom: low GPU utilization.
- Proof: removing the fault and rerunning the same workload restores results.
- Prevention: workload isolation, QoS/capacity planning, concurrency
  visibility, aligned application/storage/network telemetry and baselines.

Explain that the delay injection is a portable teaching mechanism. It does not
claim to emulate VAST internals or establish VAST performance limits.
