# VAST Storage workshop — Ubuntu VM examples

These examples generate client, workload, protocol, and network evidence on an
Ubuntu 24.04 training VM. They do not emulate VAST internals. Use VMS for native
VAST health, capacity, alarms, events, Views, and performance evidence.

## Safety model

- Use only an isolated training VM and an approved test directory.
- Never point write tests at `/`, a home directory, or an existing dataset.
- Write tests require both:
  - `ALLOW_WRITE_TESTS=YES` in `lab.env`
  - an empty sentinel file named `.vast-training-lab-approved` in `TARGET_DIR`
- Fault injection requires `CONFIRM_CONTROLLED_LAB=YES`.
- The netem demo rolls itself back and refuses the default-route interface unless
  `ALLOW_DEFAULT_ROUTE_NETEM=YES` is explicitly set.
- The NFS recovery drill controls only the Ubuntu VM's local
  `nfs-kernel-server` service. It does not stop or modify a VAST service.

## Quick start

```bash
cd vm-code-examples
cp lab.env.example lab.env
nano lab.env

./scripts/00-install-tools.sh
./scripts/01-preflight.sh
./scripts/02-protocol-checks.sh
```

For write demonstrations, create a new empty directory and approve only that
directory:

```bash
sudo mkdir -p /var/tmp/vast-training-target
sudo chown "$USER":"$(id -gn)" /var/tmp/vast-training-target
touch /var/tmp/vast-training-target/.vast-training-lab-approved
```

Then set these values in `lab.env`:

```bash
TARGET_DIR=/var/tmp/vast-training-target
ALLOW_WRITE_TESTS=YES
```

## Recommended trainer sequence

| Demonstration | Command | Main observation |
|---|---|---|
| VM preflight | `./scripts/01-preflight.sh` | Identity, resources, route, tools, free space |
| Protocol gates | `./scripts/02-protocol-checks.sh` | Connectivity vs authentication vs namespace |
| Monitoring stack | `docker compose -f monitoring/docker-compose.yml up -d` | Ubuntu CPU, memory, network, and disk panels |
| Small I/O validation | `./scripts/03-fio-smoke.sh` | Correct path, basic latency, errors |
| Sequential vs random | `./scripts/04-fio-profiles.sh` | MB/s vs IOPS and tail latency |
| Queue-depth sweep | `./scripts/05-queue-depth-sweep.sh` | Throughput knee and P99 growth |
| Client telemetry | `DURATION=30 ./scripts/06-capture-client-metrics.sh` | CPU, memory, I/O, and network evidence |
| Packet capture | `./scripts/07-packet-capture.sh` | Protocol timing, retransmits, resets |
| Client contention | `./scripts/08-resource-contention-demo.sh` | Client pressure can resemble storage latency |
| Network impairment | `./scripts/09-netem-demo.sh demo` | RTT/loss effect and verified rollback |
| Local service recovery | `./scripts/10-local-nfs-service-drill.sh` | Preserve → stop → reproduce → restore → prove |
| Evidence bundle | `./scripts/11-collect-evidence.sh` | UTC-aligned, checksummed diagnostic bundle |

Generated results are written to `artifacts/`. Review bundles for credentials,
personal data, internal addresses, and packet payload scope before sharing.

The monitoring compose file uses `latest` tags for portability. Pin
organization-approved image versions or digests before a repeatable class.
