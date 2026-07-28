# PromQL examples for the trainer dashboard

Start the stack:

```bash
docker compose -f monitoring/docker-compose.yml up -d
docker compose -f monitoring/docker-compose.yml ps
```

Open Prometheus at `http://<vm-ip>:9090` and Grafana at
`http://<vm-ip>:3000`. Add Prometheus as a Grafana data source using
`http://prometheus:9090`.

For repeatable classes, replace the `latest` container tags with versions or
digests approved by your organization.

## CPU busy percentage

```promql
100 * (1 - avg by (instance) (
  rate(node_cpu_seconds_total{mode="idle"}[1m])
))
```

## Available memory percentage

```promql
100 * node_memory_MemAvailable_bytes
  / node_memory_MemTotal_bytes
```

## Network receive throughput

```promql
rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*"}[1m])
```

## Network transmit throughput

```promql
rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*"}[1m])
```

## Network errors and drops

```promql
rate(node_network_receive_errs_total{device!="lo"}[1m])
+ rate(node_network_receive_drop_total{device!="lo"}[1m])
+ rate(node_network_transmit_errs_total{device!="lo"}[1m])
+ rate(node_network_transmit_drop_total{device!="lo"}[1m])
```

## Device I/O utilization

```promql
100 * rate(node_disk_io_time_seconds_total[1m])
```

## Read and write throughput by device

```promql
rate(node_disk_read_bytes_total[1m])
```

```promql
rate(node_disk_written_bytes_total[1m])
```

Stop the stack after the class:

```bash
docker compose -f monitoring/docker-compose.yml down
```

