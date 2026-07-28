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
