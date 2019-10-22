# Precondition:
# (1) QAT device(e.g. 37c8) installed
# (2) Enable grub with "intel_iommu=on iommu=pt"
# (3) Driver install script is put at the same folder of QAT build target

# QAT package: https://01.org/zh/intel-quick-assist-technology/downloads

# 1.install qat driver
cd driver
./install_qat.sh

# 2.install qat device plugin
# 2.1 for dpdp mode
# pre-pull local build docker image: intel-qat-plugin:devel
cd yaml
cat qat_plugin_default_configmap.yaml | kubectl apply -f -
cat qat_plugin_privileges.yaml | kubectl apply -f -

# 2.2 for kernel mode
sudo sed -i "s/\[SSL\]/\[SSL${dev_id}\]/g" /etc/c6xxvf_dev${dev_id}.conf
cd yaml
cat qat_plugin_kernel_mode.yaml | kubectl apply -f -

# 3. test
# 3.1 test qat dpdk mode
# pre-pull local build docker image: crypto-perf:devel
cd test
cat test.yaml | kubectl apply -f -
kubectl exec -it dpdk2 bash
./dpdk-test-crypto-perf -l 6-7 -w $QAT1 -- --ptest throughput\
 --devtype crypto_qat --optype cipher-only --cipher-algo aes-cbc\
 --cipher-op encrypt --cipher-key-sz 16 --total-ops 10000000\
 --burst-sz 32 --buffer-sz 64

# 3.2 test qat kernel mode
cd test
cat test_kerneldrv.yaml | kubectl apply -f -
env | grep QAT

