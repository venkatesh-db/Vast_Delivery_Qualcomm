# Trainer runbook

## 1. Establish the baseline

Run `01-preflight.sh`, then ask participants to identify:

- the UTC timestamp;
- CPU and memory available to the workload;
- the selected route and interface;
- free space in the approved test directory;
- missing tools or unhealthy services.

## 2. Prove protocol access in order

Run `02-protocol-checks.sh`. Use the output to separate:

1. name, route, and port connectivity;
2. authentication;
3. authorization and ACLs;
4. exact path or object-key lookup;
5. payload I/O.

Do not “fix permissions” until the failed gate and intended policy are known.

## 3. Demonstrate workload shape

Run `03-fio-smoke.sh` before a longer test. Run `04-fio-profiles.sh` and compare:

- sequential MB/s;
- 4 KiB random IOPS;
- average latency;
- P95/P99 latency;
- errors and client resource use.

The values are lab observations, not VAST performance limits.

## 4. Find the queue-depth knee

Run `05-queue-depth-sweep.sh`. Plot or discuss the generated CSV. The useful
operating point is where additional concurrency stops producing proportional
throughput and tail latency begins to grow sharply.

## 5. Correlate client evidence

Run `06-capture-client-metrics.sh` beside an fio workload. Align every file by
UTC time. Show why application latency alone cannot identify a storage cause.

## 6. Observe packets before injecting a fault

Run `07-packet-capture.sh`. Open the pcap in Wireshark if available. Minimize the
capture filter and duration; a pcap may contain sensitive payload or identity
information.

## 7. Controlled client contention

Set `CONFIRM_CONTROLLED_LAB=YES`, then run
`08-resource-contention-demo.sh`. Compare baseline, contended, and recovered
fio/host metrics. The explanation should identify the constrained client
resource, not merely state that latency increased.

## 8. Controlled network impairment

Use a secondary interface, veth pair, or Docker bridge. Run:

```bash
./scripts/09-netem-demo.sh demo
```

The script automatically deletes its own netem qdisc. Verify the final qdisc and
RTT before declaring recovery.

## 9. Preserve state before service recovery

On a disposable Ubuntu NFS server VM only:

```bash
./scripts/10-local-nfs-service-drill.sh
```

The service is restored by an EXIT trap even if the drill is interrupted.

## 10. Build the handoff bundle

Run `11-collect-evidence.sh`. A useful handoff includes impact, exact
path/identity, UTC timeline, raw evidence, causal mechanism, recovery action,
rollback, validation, and prevention owner.

