# Ubuntu 24.04 AMD64 verification

Verification date: 2026-07-28 UTC

## Test environment

- Official `ubuntu:24.04` container userland
- Architecture reported inside the test: `x86_64`
- fio 3.36
- Python 3.12.3
- No NVIDIA GPU exposed; the labelled simulated GPU metric was tested

The container used a LinuxKit host kernel rather than
`7.0.0-28-generic`. The project uses standard Ubuntu user-space interfaces and
does not depend on a particular kernel patch level. The screenshot environment
(`Ubuntu 24.04`, `x86_64`) is therefore within the supported target.

## End-to-end result

| Check | Result |
|---|---|
| Package installation | Pass |
| OS/architecture preflight | Pass |
| Dataset and contention-file preparation | Pass |
| Baseline workload | Pass |
| Competing small-block fio workload | Pass |
| Degraded training workload | Pass |
| Fault removal | Pass |
| Same-workload recovery | Pass |
| Markdown and CSV report generation | Pass |
| Explicit confirmation safety guard | Pass |
| Sentinel-protected cleanup | Pass |
| Shell syntax and Python compilation | Pass |

Observed final-test values:

| Phase | Elapsed | Dataset rate | Simulated GPU |
|---|---:|---:|---:|
| Baseline | 3.84 s | 20.8 MiB/s | 87.2% |
| Degraded | 7.19 s | 11.1 MiB/s | 46.5% |
| Recovered | 4.09 s | 19.5 MiB/s | 87.1% |

The emulated AMD64 test produced a 1.87× slowdown, a projected 3.0-hour to
5.6-hour change, and complete recovery within the configured tolerance.
Scheduling and I/O overhead under architecture emulation lowered the baseline
teaching metric. On a native Ubuntu VM, the supplied timing model is expected
to be closer to the nominal 95% → 45% signal. Exact values are intentionally
reported rather than hard-coded.

## Boundary of verification

The test proves Ubuntu 24.04 AMD64 execution, process cleanup and evidence
generation. It does not certify:

- a customer VAST mount, network or VMS configuration;
- a physical NVIDIA GPU or its driver;
- production performance limits;
- exact results on every VM/storage combination.

Run `01-preflight.sh` once on the instructor VM and perform a rehearsal using
the final disposable VAST training path before class.
