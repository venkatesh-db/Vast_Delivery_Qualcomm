

sudo apt install -y \
  nfs-common \
  nfs-kernel-server \
  lvm2 \
  sysstat \
  iotop \
  dstat \
  fio \
  iperf3 \
  net-tools \
  ethtool \
  hping3 \
  nmap \
  traceroute \
  nload \
  irqbalance \
  cifs-utils \
  smbclient \
  nvme-cli \
  iproute2 \
  util-linux \
  lshw \
  bc \
  tree \
  curl \
  wget




## 0. Install everything first

```bash
sudo apt update
sudo apt install -y nfs-common cifs-utils fio sysstat iperf3 tcpdump \
    ethtool iproute2 nfs4-acl-tools smbclient net-tools bc jq
```

`sysstat` needs enabling for historical data:
```bash
sudo sed -i 's/ENABLED="false"/ENABLED="true"/' /etc/default/sysstat
sudo systemctl enable --now sysstat
```

---

## Module 5 — NFS client

**Discovery**
```bash
showmount -e 10.0.0.50                  # exports on server
rpcinfo -p 10.0.0.50                    # portmapper / which NFS versions
nfsstat -m                              # mounted FS + negotiated options (KEY command)
```

**Manual mount**
```bash
sudo mkdir -p /mnt/nfs
sudo mount -t nfs -o vers=4.2 10.0.0.50:/export/data /mnt/nfs
sudo mount -t nfs -o vers=3,proto=tcp 10.0.0.50:/export/data /mnt/nfs
mount | grep nfs                        # verify actual options applied
```

**Option tuning — the lab that matters**
```bash
# large sequential — max transfer size
sudo mount -t nfs -o rsize=1048576,wsize=1048576,hard,timeo=600,retrans=2 \
    10.0.0.50:/export/data /mnt/nfs

# deliberately crippled, for comparison
sudo mount -t nfs -o rsize=8192,wsize=8192 10.0.0.50:/export/data /mnt/nfs2

# metadata-heavy workload tuning
sudo mount -t nfs -o actimeo=600,nocto,lookupcache=all 10.0.0.50:/export/data /mnt/nfs

# soft mount — demo only, show the risk
sudo mount -t nfs -o soft,timeo=50,retrans=2 10.0.0.50:/export/data /mnt/nfs
```

Teaching point: server negotiates down. Request `rsize=1048576`, run `nfsstat -m`, show what you actually got.

**hard vs soft demo** (run on client, block server with firewall):
```bash
sudo iptables -A OUTPUT -d 10.0.0.50 -p tcp --dport 2049 -j DROP
dd if=/dev/zero of=/mnt/nfs/test bs=1M count=100   # hard: hangs. soft: EIO
sudo iptables -D OUTPUT -d 10.0.0.50 -p tcp --dport 2049 -j DROP
```

**nfsstat analysis**
```bash
nfsstat -c                              # client RPC + per-op counts
nfsstat -cn                             # NFS calls only
nfsstat -o all -l                       # everything, list form
watch -n1 'nfsstat -c | head -20'       # live delta during a load run

# RPC retransmits — the number to watch
nfsstat -rc
cat /proc/self/mountstats               # per-mount RTT + queue time per op
mountstats --nfs /mnt/nfs               # if nfs-utils version supports it
```

Key diagnostic: `retrans` climbing = network loss or server overload. `badcalls` = errors.

**/etc/fstab**
```
10.0.0.50:/export/data  /mnt/nfs  nfs4  rw,hard,rsize=1048576,wsize=1048576,timeo=600,retrans=2,_netdev,noatime  0 0
10.0.0.50:/export/lazy  /mnt/lazy nfs4  rw,noauto,x-systemd.automount,_netdev  0 0
```
```bash
sudo mount -a                           # test WITHOUT rebooting
sudo systemctl daemon-reload            # required after fstab edits
findmnt -t nfs4                         # tree view of what mounted
```
Always teach `_netdev` and `mount -a` before reboot — a bad fstab line hangs boot.

---

## Modules 3 & 8 — Performance measurement

**Baseline with dd** (crude, sequential only, good for a first number)
```bash
# write — bypass page cache
dd if=/dev/zero of=/mnt/nfs/ddtest bs=1M count=4096 oflag=direct status=progress

# read — drop cache first
sync; echo 3 | sudo tee /proc/sys/vm/drop_caches
dd if=/mnt/nfs/ddtest of=/dev/null bs=1M status=progress
```
Teaching point: `dd` without `oflag=direct` measures RAM, not storage. Show both numbers.

**fio — the real tool**

Sequential read throughput:
```bash
fio --name=seqread --directory=/mnt/nfs --rw=read --bs=1M --size=4G \
    --numjobs=4 --iodepth=16 --ioengine=libaio --direct=1 \
    --runtime=60 --time_based --group_reporting
```

Sequential write:
```bash
fio --name=seqwrite --directory=/mnt/nfs --rw=write --bs=1M --size=4G \
    --numjobs=4 --iodepth=16 --ioengine=libaio --direct=1 \
    --runtime=60 --time_based --group_reporting
```

Random read IOPS:
```bash
fio --name=randread --directory=/mnt/nfs --rw=randread --bs=4k --size=4G \
    --numjobs=8 --iodepth=32 --ioengine=libaio --direct=1 \
    --runtime=60 --time_based --group_reporting
```

Latency profile (QD1 — this is the honest latency number):
```bash
fio --name=lat --directory=/mnt/nfs --rw=randread --bs=4k --size=1G \
    --numjobs=1 --iodepth=1 --ioengine=psync --direct=1 \
    --runtime=60 --time_based --percentile_list=50:95:99:99.9
```

Mixed OLTP-style:
```bash
fio --name=mixed --directory=/mnt/nfs --rw=randrw --rwmixread=70 --bs=8k \
    --size=4G --numjobs=8 --iodepth=16 --ioengine=libaio --direct=1 \
    --runtime=120 --time_based --group_reporting
```

Metadata / small-file storm (exposes NFS weakness beautifully):
```bash
fio --name=meta --directory=/mnt/nfs --rw=randwrite --bs=4k \
    --nrfiles=10000 --filesize=4k --numjobs=4 --ioengine=sync --create_on_open=1
```

Job file form (better for repeatable labs):
```bash
cat > /tmp/seq.fio <<'EOF'
[global]
directory=/mnt/nfs
ioengine=libaio
direct=1
time_based
runtime=60
group_reporting

[seqread]
rw=read
bs=1M
size=2G
numjobs=4
iodepth=16
EOF

fio /tmp/seq.fio --output-format=json --output=/tmp/seq.json
jq '.jobs[0].read | {bw_MBps: (.bw/1024), iops, lat_us_p99: .clat_ns.percentile."99.000000"/1000}' /tmp/seq.json
```

Reading fio output — the three numbers: `bw=` (throughput), `iops=`, `clat percentiles` (latency). p99 is the one that matters, not avg.

**iostat**
```bash
iostat -x 1                             # extended, per-second
iostat -xz 1 10                         # skip idle devices
iostat -dx nvme0n1 1                    # single device
iostat -h -n 1                          # NFS mount stats specifically
```
Columns to teach: `%util`, `aqu-sz` (queue depth), `r_await`/`w_await` (ms latency), `rareq-sz`/`wareq-sz` (actual I/O size — proves whether rsize took effect).

Run fio in one pane, `iostat -x 1` in another. That side-by-side is the lesson.

**Supporting**
```bash
sar -d 1 5                              # historical disk
sar -n DEV 1 5                          # historical network
pidstat -d 1                            # per-process I/O
vmstat 1                                # bi/bo, context switches, wait
mpstat -P ALL 1                         # %iowait, %soft — softirq = network bottleneck
```

---

## Module 4 — Network analysis

**iperf3 baseline — always do this before blaming storage**
```bash
# server side
iperf3 -s -p 5201

# client — single stream
iperf3 -c 10.0.0.50 -t 30 -i 1

# parallel streams — reveals single-stream vs aggregate ceiling
iperf3 -c 10.0.0.50 -P 8 -t 30

# reverse (server→client, mimics NFS read)
iperf3 -c 10.0.0.50 -R -t 30

# bidirectional
iperf3 -c 10.0.0.50 --bidir -t 30

# UDP — loss and jitter
iperf3 -c 10.0.0.50 -u -b 1G -t 30

# JSON for scripting
iperf3 -c 10.0.0.50 -t 30 -J > /tmp/iperf.json
jq '.end.sum_received.bits_per_second/1e9' /tmp/iperf.json
```
Teaching point: if iperf3 gives 9.4 Gbps and fio gives 200 MB/s, the network is not your problem.

**ethtool**
```bash
ethtool ens160                          # speed, duplex, link
ethtool -S ens160 | grep -Ei 'err|drop|discard|miss|fifo|crc'   # THE command
ethtool -g ens160                       # ring buffer size (current vs max)
ethtool -G ens160 rx 4096 tx 4096       # raise rings if rx_dropped climbing
ethtool -k ens160                       # offloads: GRO, GSO, TSO, LRO
ethtool -c ens160                       # interrupt coalescing
ethtool -i ens160                       # driver + firmware version
ethtool -l ens160                       # queue/channel count
```

**Interface utilization**
```bash
ip -s link show ens160                  # RX/TX bytes, errors, dropped
sar -n DEV 1 5                          # rate form
sar -n EDEV 1 5                         # error rates
nstat -az | grep -Ei 'retrans|drop|prune|overflow'
cat /proc/net/softnet_stat              # col2 nonzero = backlog drops
netstat -su                             # UDP receive errors (matters for NFSv3/UDP)
```

**ss — socket state**
```bash
ss -tin                                 # TCP internals: cwnd, rtt, retrans
ss -tin dst 10.0.0.50                   # just the NFS server
ss -tn state established '( dport = :2049 )'
ss -s                                   # summary counts
ss -tm                                  # socket memory / buffer pressure
watch -n1 "ss -tin dst 10.0.0.50 | grep -o 'retrans:[0-9/]*'"
```
Fields to teach: `rtt:`, `cwnd:`, `retrans:`, `bytes_retrans`. Rising retrans = congestion or loss.

**tcpdump**
```bash
# capture NFS traffic to file — never analyse live on a busy link
sudo tcpdump -i ens160 -w /tmp/nfs.pcap -s 0 host 10.0.0.50 and port 2049 -c 20000

# SMB
sudo tcpdump -i ens160 -w /tmp/smb.pcap port 445 and host 10.0.0.50

# ring buffer, bounded disk use
sudo tcpdump -i ens160 -w /tmp/cap.pcap -C 100 -W 5 port 2049

# quick live look — retransmissions only
sudo tcpdump -i ens160 -nn 'tcp[tcpflags] & tcp-rst != 0'

# zero-window (receiver stalled)
sudo tcpdump -i ens160 -nn 'tcp[14:2] = 0 and port 2049'

# read back
tcpdump -r /tmp/nfs.pcap -nn | head -50
tcpdump -r /tmp/nfs.pcap -nn -A | grep -i nfs
```

**Congestion / path**
```bash
mtr -rwzc 100 10.0.0.50                 # loss per hop
ping -M do -s 8972 10.0.0.50            # jumbo frame / MTU verification
tracepath 10.0.0.50                     # discovers path MTU
sysctl net.ipv4.tcp_congestion_control
sysctl net.core.rmem_max net.core.wmem_max
sysctl net.ipv4.tcp_rmem net.ipv4.tcp_wmem
```
MTU test is a classic lab: `ping -M do -s 8972` fails → jumbo frames are misconfigured somewhere on the path, and NFS throughput will be mysteriously bad.

---

## Module 5 — SMB client

**Discovery + auth testing**
```bash
smbclient -L //10.0.0.60 -U alice                   # list shares
smbclient -L //10.0.0.60 -N                         # anonymous
smbclient //10.0.0.60/share -U 'DOMAIN\alice'       # interactive session
smbclient //10.0.0.60/share -U alice -c 'ls; get bigfile'
smbclient //10.0.0.60/share -U alice -m SMB3        # force protocol version
smbclient //10.0.0.60/share -U alice -d 3           # debug level for auth failures
```

**Mounting**
```bash
sudo mkdir -p /mnt/smb
sudo mount -t cifs //10.0.0.60/share /mnt/smb \
    -o username=alice,password=secret,vers=3.1.1,uid=1000,gid=1000

# credentials file — the correct way
sudo tee /etc/cifs-creds-alice >/dev/null <<'EOF'
username=alice
password=secret
domain=CORP
EOF
sudo chmod 600 /etc/cifs-creds-alice

sudo mount -t cifs //10.0.0.60/share /mnt/smb \
    -o credentials=/etc/cifs-creds-alice,vers=3.1.1,seal,iocharset=utf8

# performance-relevant options
-o cache=strict          # default, safe
-o cache=none            # correctness over speed
-o rsize=1048576,wsize=1048576
-o nosharesock           # separate TCP per mount
-o multichannel,max_channels=4
-o seal                  # SMB3 encryption — measure the CPU cost, it's real
```

**fstab**
```
//10.0.0.60/share  /mnt/smb  cifs  credentials=/etc/cifs-creds-alice,vers=3.1.1,_netdev,uid=1000,gid=1000,nofail  0 0
```

**Verify + diagnose**
```bash
mount | grep cifs
cat /proc/fs/cifs/DebugData                          # sessions, dialect, capabilities
sudo modprobe cifs; echo 7 | sudo tee /proc/fs/cifs/cifsFYI   # verbose debug on
dmesg -w | grep -i cifs                              # errors land here
echo 0 | sudo tee /proc/fs/cifs/cifsFYI              # turn it off, it's noisy
cat /proc/fs/cifs/Stats                              # per-share op counts
```
Auth failure triage: `NT_STATUS_LOGON_FAILURE` = creds. `NT_STATUS_ACCESS_DENIED` = share/NTFS perms. `mount error(112)` = host down/firewall. Teach the mapping explicitly.

---

## Module 9 — Log analysis

**journalctl**
```bash
journalctl -u nfs-client.target -n 100 --no-pager
journalctl -k --since "1 hour ago"                   # kernel only
journalctl -p err --since today                      # errors and worse
journalctl --since "2026-08-04 09:00" --until "2026-08-04 10:00"
journalctl -f -k | grep -Ei 'nfs|cifs|timeout|reset'
journalctl -k -o short-precise                       # microsecond timestamps for correlation
journalctl --disk-usage; journalctl --vacuum-time=7d
```

**grep patterns that earn their keep**
```bash
grep -Ei 'nfs.*(not responding|timed out|server ok)' /var/log/syslog
grep -c 'nfs: server .* not responding' /var/log/syslog
dmesg -T | grep -Ei 'nfs|cifs|call graph|hung task'
grep -rn 'CIFS VFS' /var/log/syslog | tail -20
```
`server not responding` followed by `server OK` bracket an outage window — teach extracting that pair.

**awk — turn logs into numbers**
```bash
# events per minute
awk '{print $1, $2, substr($3,1,5)}' /var/log/syslog | sort | uniq -c | sort -rn | head

# extract + average a latency field
awk '/latency/ {sum+=$NF; n++} END {printf "avg=%.2f n=%d\n", sum/n, n}' /var/log/app.log

# p95 from a log column
awk '/latency/ {print $NF}' /var/log/app.log | sort -n | awk '{a[NR]=$1} END {print "p95:", a[int(NR*0.95)]}'

# top error messages
grep -i error /var/log/syslog | awk -F': ' '{print $NF}' | sort | uniq -c | sort -rn | head

# histogram by hour
awk '{split($3,t,":"); print t[1]":00"}' /var/log/syslog | uniq -c
```

**Correlation — the actual Module 9 skill**
```bash
# 1. get the incident window from the log
grep 'not responding' /var/log/syslog | head -1

# 2. pull every source for that window, same timebase
journalctl -k --since "09:14:00" --until "09:22:00" -o short-precise > /tmp/kern.txt
sar -n DEV -s 09:14:00 -e 09:22:00 > /tmp/net.txt
sar -d -s 09:14:00 -e 09:22:00 > /tmp/disk.txt
sar -q -s 09:14:00 -e 09:22:00 > /tmp/load.txt

# 3. merge on timestamp
paste /tmp/net.txt /tmp/disk.txt | less -S
```
Force everything to UTC or force everything to local, and use `-o short-precise`. Mixed timezones destroy more incident analyses than any other single mistake.

---

## Module 3 — Workload profiling: seq vs random, side by side

Run this as one script — the comparison is the teaching artifact, not the individual numbers.

```bash
#!/bin/bash
TARGET=${1:-/mnt/nfs}
OUT=/tmp/profile-$(date +%H%M%S)
mkdir -p $OUT

run() {
  echo "=== $1 ==="
  sync; echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
  fio --name=$1 --directory=$TARGET --direct=1 --ioengine=libaio \
      --runtime=45 --time_based --group_reporting --size=2G \
      --output-format=json --output=$OUT/$1.json "${@:2}"
}

run seq_read_1m   --rw=read      --bs=1M --numjobs=4 --iodepth=16
run seq_write_1m  --rw=write     --bs=1M --numjobs=4 --iodepth=16
run rand_read_4k  --rw=randread  --bs=4k --numjobs=8 --iodepth=32
run rand_write_4k --rw=randwrite --bs=4k --numjobs=8 --iodepth=32
run mixed_8k_70r  --rw=randrw --rwmixread=70 --bs=8k --numjobs=8 --iodepth=16

printf "\n%-16s %10s %10s %12s\n" WORKLOAD MB/s IOPS p99_us
for f in $OUT/*.json; do
  jq -r --arg n "$(basename $f .json)" '
    .jobs[0] as $j |
    (($j.read.bw + $j.write.bw)/1024) as $bw |
    ($j.read.iops + $j.write.iops) as $io |
    (($j.read.clat_ns.percentile."99.000000" // $j.write.clat_ns.percentile."99.000000")/1000) as $p |
    "\($n)|\($bw)|\($io)|\($p)"' $f |
  awk -F'|' '{printf "%-16s %10.1f %10.0f %12.0f\n", $1, $2, $3, $4}'
done
```

Block-size sweep (shows where rsize/wsize starts mattering):
```bash
for bs in 4k 16k 64k 256k 1M; do
  fio --name=bs_$bs --directory=/mnt/nfs --rw=read --bs=$bs --size=2G \
      --numjobs=4 --iodepth=16 --direct=1 --ioengine=libaio \
      --runtime=30 --time_based --group_reporting \
      | grep -E 'READ:|clat percentiles' 
done
```

Queue-depth sweep (finds the latency knee — the single most useful chart in the module):
```bash
for qd in 1 2 4 8 16 32 64; do
  echo "QD=$qd"
  fio --name=qd$qd --directory=/mnt/nfs --rw=randread --bs=4k --size=2G \
      --numjobs=1 --iodepth=$qd --direct=1 --ioengine=libaio \
      --runtime=30 --time_based | grep -E 'iops=|99.00th'
done
```

---

## The lab sequence that ties it together

1. `iperf3` → establish network ceiling.
2. `nfsstat -m` → record negotiated mount options.
3. `fio` seq + random → record throughput/IOPS/p99.
4. Remount with `rsize=8192` → rerun step 3 → compare.
5. `iostat -x 1` + `ss -tin` during the run → find where the queue builds.
6. `tcpdump` + `ethtool -S` → confirm or eliminate loss/drops.
7. `journalctl -k` correlated to the run window → confirm no kernel-level events.

Rule to give students: never tune the mount before you've measured the network. Most "NFS is slow" tickets are MTU mismatch, an errored NIC, or a single-stream TCP ceiling — not `rsize`.



Completed the `VAST Admin Simulator` with all 15 production-incident scenarios.

### Ubuntu verification

Tested using the official Ubuntu 24.04 AMD64 container:

```text
INSTALL: PASS
TEST SUITE: PASS
ALL SCENARIOS: PASS (15/15)
Container exit code: 0
```

Six automated tests passed:

- Broad/root-directory safety rejection
- Symlink and path-escape rejection
- Exactly 15 valid scenario definitions
- Out-of-order phase rejection
- All 15 state machines reaching verified PASS
- Physical workloads remaining within safety limits

### Run on Ubuntu

```bash
unzip VAST_Admin_Simulator_15_Scenarios_Ubuntu.zip
cd vast-admin-simulator

chmod +x bin/vast-sim install-ubuntu.sh run-all.sh tests/*.sh

./install-ubuntu.sh
./bin/vast-sim list
./tests/run-tests.sh
./run-all.sh
```

Run one complete scenario:

```bash
./bin/vast-sim run 1
```

For an instructor-led investigation:

```bash
./bin/vast-sim phase 1 baseline
./bin/vast-sim phase 1 incident
./bin/vast-sim phase 1 diagnose
./bin/vast-sim phase 1 recover
./bin/vast-sim phase 1 verify
```

The simulator refuses phases executed in the wrong order.

### Production-readiness boundary

This is production-quality **training code**, with:

- Bounded disposable workloads
- Safety and path-containment controls
- Atomic JSON evidence
- Scenario execution locks
- UTC timestamps
- Deterministic recovery
- Automated verification
- Explicit evidence provenance

Every result is labelled:

```text
CLIENT_CONTROLLED
SIMULATED_VMS
REAL_VAST: NOT_CONNECTED
```

It does not modify real VAST Views, policies, quotas, snapshots, exports, replication, hardware, alerts or software. Genuine production VAST administration still requires an authorized non-production cluster and version-matched official procedures.





Yes—the listed steps will work on your Ubuntu 24.04 VM, provided you use the exact configuration and disposable directory.

Your VM has local `ext4`, sufficient free space and all required commands can be installed. These scripts were also previously tested on Ubuntu 24.04.

Before running, verify the configuration:

```bash
cd ~/Downloads/vm-code-examples

grep -E '^(TARGET_DIR|ALLOW_WRITE_TESTS|KEEP_TEST_DATA|DURATION|FIO_SIZE|CONFIRM_CONTROLLED_LAB)=' lab.env

test -f /var/tmp/vast-training-target/.vast-training-lab-approved \
  && echo "SENTINEL PASS" \
  || echo "SENTINEL MISSING"

test -w /var/tmp/vast-training-target \
  && echo "WRITE ACCESS PASS" \
  || echo "WRITE ACCESS FAILED"
```

Expected:

```text
TARGET_DIR=/var/tmp/vast-training-target
ALLOW_WRITE_TESTS=YES
KEEP_TEST_DATA=NO
CONFIRM_CONTROLLED_LAB=YES
DURATION=10
FIO_SIZE=128M
SENTINEL PASS
WRITE ACCESS PASS
```

Then run:

```bash
./scripts/01-preflight.sh
./scripts/02-protocol-checks.sh
./scripts/03-fio-smoke.sh
./scripts/04-fio-profiles.sh
./scripts/05-queue-depth-sweep.sh
DURATION=10 ./scripts/06-capture-client-metrics.sh
DURATION=10 CPU_WORKERS=1 VM_WORKERS=1 VM_BYTES=10% ./scripts/08-resource-contention-demo.sh
./scripts/11-collect-evidence.sh
```

Approximate duration: 2–3 minutes.

Expected results:

- `01`: preflight report created
- `02`: local path validated; this does not prove NFS/VAST connectivity
- `03`: FIO JSON with `"errors": 0`
- `04`: four FIO profile JSON files and `summary.csv`
- `05`: five queue-depth results and `summary.csv`
- `06`: `vmstat`, `iostat`, `pidstat` and network metrics
- `08`: bounded contention finishes automatically after 10 seconds
- `11`: evidence archive and SHA-256 checksum created

Final verification:

```bash
find artifacts -maxdepth 2 -type f | sort

grep -R '"error": [1-9]' artifacts --include='*.json' \
  && echo "FIO ERROR FOUND" \
  || echo "ALL FIO RESULTS CLEAN"
```

Expected final line:

```text
ALL FIO RESULTS CLEAN
```

This confirms scripts `01–06`, `08`, and `11`. Scripts `07`, `09`, and `10` remain intentionally excluded until a safe packet-capture interface, isolated network interface and local NFS server are available.



Yes. Copy the commands below into the Ubuntu terminal.

These commands use only a disposable local directory. Do not point them at production data.

## Step 1 — Open the project

```bash
cd ~/Downloads/vm-code-examples
pwd
ls scripts
```

## Step 2 — Install the required programs

```bash
chmod +x scripts/*.sh
./scripts/00-install-tools.sh
```

Enter your Ubuntu password when requested.

## Step 3 — Prepare the safe test directory

```bash
sudo mkdir -p /var/tmp/vast-training-target
sudo chown "$USER":"$(id -gn)" /var/tmp/vast-training-target
touch /var/tmp/vast-training-target/.vast-training-lab-approved
```

## Step 4 — Configure the project

```bash
cp -n lab.env.example lab.env
nano lab.env
```

Replace the content with:

```bash
TARGET_DIR=/var/tmp/vast-training-target
ALLOW_WRITE_TESTS=YES
KEEP_TEST_DATA=NO

NFS_TEST_PATH=/var/tmp/vast-training-target
SMB_SERVER=
SMB_SHARE=
SMB_AUTH_FILE=
S3_OBJECT=
MINIO_HEALTH_URL=

LAB_IF=
TARGET_HOST=
BPF_FILTER=

CONFIRM_CONTROLLED_LAB=YES
ALLOW_DEFAULT_ROUTE_NETEM=NO

DURATION=10
FIO_SIZE=128M
ARTIFACT_DIR=
```

Save with `Ctrl+O`, press Enter, then exit using `Ctrl+X`.

## Step 5 — Run scripts 01–06

Run each command individually:

```bash
./scripts/01-preflight.sh
```

```bash
./scripts/02-protocol-checks.sh
```

```bash
./scripts/03-fio-smoke.sh
```

```bash
./scripts/04-fio-profiles.sh
```

```bash
./scripts/05-queue-depth-sweep.sh
```

```bash
DURATION=10 ./scripts/06-capture-client-metrics.sh
```

## Step 6 — Run script 08

```bash
DURATION=10 CPU_WORKERS=1 VM_WORKERS=1 VM_BYTES=10% \
./scripts/08-resource-contention-demo.sh
```

## Step 7 — Collect the results

```bash
./scripts/11-collect-evidence.sh
```

View generated files:

```bash
find artifacts -maxdepth 2 -type f | sort
```

For now, skip scripts `07`, `09`, and `10`. They require packet-capture configuration, network fault injection, or a local NFS server. Scripts `01–06`, `08`, and `11` can be safely tested using the disposable Ubuntu directory above.



unzip VAST_Storage_VM_Code_Examples.zip
cd vm-code-examples

cp lab.env.example lab.env
./scripts/00-install-tools.sh
./scripts/01-preflight.sh

./scripts/02-protocol-checks.sh
./scripts/03-fio-smoke.sh
./scripts/04-fio-profiles.sh
./scripts/05-queue-depth-sweep.sh
./scripts/06-capture-client-metrics.sh
./scripts/07-packet-capture.sh
./scripts/11-collect-evidence.sh

./scripts/08-resource-contention-demo.sh
./scripts/09-netem-demo.sh demo
./scripts/10-local-nfs-service-drill.sh

CONFIRM_CONTROLLED_LAB=YES


Project 1 

sudo apt-get install -y unzip

unzip VAST_AI_Training_Degradation_Ubuntu.zip
cd scenario1-ai-training-performance

cp config.env.example config.env
./scripts/00-install-tools.sh
./run-demo.sh


Project2

sudo apt-get install -y unzip

unzip VAST_AI_Dataset_Access_Failure_Ubuntu.zip
cd scenario2-ai-dataset-access-failure

cp config.env.example config.env
./scripts/00-install-tools.sh
./run-demo.sh
