# Ubuntu 24.04 functional test report

Test date: 2026-07-28  
Environment: official `ubuntu:24.04` ARM64 container  
Purpose: execute the workshop scripts against disposable paths with short test
durations and verify outputs, cleanup, safety blocks, and rollback.

## Results

| Script | Result | Evidence checked |
|---|---|---|
| `00-install-tools.sh` | Pass | Package update/install completed idempotently |
| `01-preflight.sh` | Pass | VM, network, filesystem, tools, and sentinel report created |
| `02-protocol-checks.sh` | Pass | Connectivity and configured-path evidence saved |
| `03-fio-smoke.sh` | Pass | JSON created, zero fio errors, test file removed |
| `04-fio-profiles.sh` | Pass | Four profile JSON files and summary CSV created |
| `05-queue-depth-sweep.sh` | Pass | QD 1/4/8/16/32 completed; CSV and P99 values created |
| `06-capture-client-metrics.sh` | Pass | vmstat, iostat, pidstat, sar, and UTC files created |
| `07-packet-capture.sh` | Pass | Valid pcap created; timeout treated as normal completion |
| `08-resource-contention-demo.sh` | Pass | Bounded stress completed and client metrics were captured |
| `09-netem-demo.sh` | Pass | netem applied and removed; final interface had no netem qdisc |
| `10-local-nfs-service-drill.sh` | Conditional pass | Stop/start/restore and evidence logic passed with a deterministic service-manager mock |
| `11-collect-evidence.sh` | Pass | Evidence directory, tar.gz archive, and SHA-256 checksum created |

Additional checks:

- 10 fio JSON job results were inspected; non-zero errors: **0**.
- Test artifacts created: **53 files**.
- Disposable fio data files remaining after cleanup: **0**.
- Active netem qdiscs after rollback: **0**.
- Write and fault-injection scripts correctly refused to run without their
  explicit approval settings.
- The monitoring Docker Compose file passed `docker compose config`.
- Every Bash script passed `bash -n`.

## Required checks on the actual training VM

The following depend on infrastructure that an isolated container cannot
faithfully reproduce:

- the real VAST/NFS endpoint and mount options;
- SMB authentication and share authorization;
- S3/MinIO credentials, bucket policy, and object keys;
- interface name and route to the actual target;
- script 10 against a real systemd-managed `nfs-kernel-server`;
- the complete Prometheus/Grafana stack using the organization's approved
  container versions.

Run `01-preflight.sh` and `02-protocol-checks.sh` on the final VM before class.
Run script 10 only on a disposable Ubuntu NFS server VM, never on a VAST node.

