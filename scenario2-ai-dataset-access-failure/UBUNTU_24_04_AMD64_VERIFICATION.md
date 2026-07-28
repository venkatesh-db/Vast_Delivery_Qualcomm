# Ubuntu 24.04 AMD64 verification

Verification date: 2026-07-28 UTC

## Test environment

- Official `ubuntu:24.04` container userland
- Architecture reported inside test: `x86_64`
- Python 3.12.3
- jq 1.7
- sysstat 12.6

The container used a LinuxKit host kernel rather than
`7.0.0-28-generic`. The project uses standard Ubuntu filesystem and user-space
interfaces and does not depend on a particular kernel patch level. The
screenshot target (`Ubuntu 24.04`, `x86_64`) is supported.

## Functional results

The full project was run twice. Both runs passed.

Representative second-run evidence:

| Phase/mapping | Successful reads | File not found | Browse P95 |
|---|---:|---:|---:|
| Baseline/current | 86 | 0 | 4.015 ms |
| Baseline/stale | 86 | 0 | 3.634 ms |
| Incident/current | 213 | 0 | 16.836 ms |
| Incident/stale | 143 | 70 | 16.702 ms |
| Recovered/current | 84 | 0 | 15.178 ms |
| Recovered/stale | 84 | 0 | 16.266 ms |

Metadata/capacity evidence:

- metadata entries increased from 100 to 1,500;
- 1,400 files were added;
- allocated data beneath the lab increased by 5,795,840 bytes;
- browsing P95 increased by more than four times;
- both clients returned to zero missing-file errors after recovery.

## Verification matrix

| Check | Result |
|---|---|
| Dependency installation | Pass |
| OS and architecture preflight | Pass |
| Safe lab preparation | Pass |
| Clean baseline for both clients | Pass |
| Canonical atomic publishing | Pass |
| Legacy delete/recreate failure injection | Pass |
| Mixed client outcome | Pass |
| Intermittent missing-file evidence | Pass |
| Metadata and allocated-byte growth | Pass |
| Slower namespace browsing | Pass |
| Stale-path preservation and correction | Pass |
| Same-client recovery retest | Pass |
| Markdown and CSV report generation | Pass |
| Repeat execution/reset | Pass |
| Missing-confirmation refusal | Pass |
| Non-empty unsentinelled-directory refusal | Pass |
| Sentinel-protected cleanup | Pass |
| Shell syntax and Python compilation | Pass |

## Boundary of verification

The test proves Ubuntu 24.04 AMD64 execution and local/mounted-filesystem
namespace behavior. It does not certify:

- a customer's VAST mount, View, export or ACL configuration;
- SMB or S3-specific behavior;
- production performance or capacity limits.

On the instructor VM, run `01-preflight.sh` and rehearse once against the final
disposable VAST training path. Correlate the generated UTC timestamps with VMS.
