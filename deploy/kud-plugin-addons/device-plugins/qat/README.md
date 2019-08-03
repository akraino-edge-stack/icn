# Precondition:
# (1) QAT device(e.g. 37c8) installed
# (2) Enable grub with "intel_iommu=on iommu=pt"
# (3) Driver install script is put at the same folder of QAT build target

# QAT package: https://01.org/zh/intel-quick-assist-technology/downloads

# install qat driver
cd driver
./install_qat.sh

# install qat device plugin
# pre-pull local build docker image: intel-qat-plugin:devel
cd yaml
cat qat_plugin_default_configmap.yaml | kubectl apply -f -
cat qat_plugin_privileges.yaml | kubectl apply -f -

# test
# pre-pull local build docker image: crypto-perf:devel
cd test
cat test.yaml | kubectl apply -f -
kubectl exec -it dpdk2 bash
./dpdk-test-crypto-perf -l 6-7 -w $QAT1 -- --ptest throughput\
 --devtype crypto_qat --optype cipher-only --cipher-algo aes-cbc\
 --cipher-op encrypt --cipher-key-sz 16 --total-ops 10000000\
 --burst-sz 32 --buffer-sz 64
