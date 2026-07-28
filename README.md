

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
