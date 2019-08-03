# Precondition: iavf.ko is pre-compiled and put in the same folder with install_iavf_driver.sh`
# Intel Network Adapter Virtual Function Driver for Intel Ethernet Controller 700 series
# https://downloadcenter.intel.com/download/24693/Intel-Network-Adapter-Virtual-Function-Driver-for-Intel-Ethernet-Controller-700-Series?product=82947

# install sriov nic driver
cd driver
./install_iavf_driver.sh $ifname

# install SRIOV device plugin
cd yaml
cat sriov-cni.yaml | kubectl apply -f -
cat sriovdp-daemonset.yaml | kubectl apply -f -

# test
cd test
cat sriov-nad.yaml | kubectl apply -f -
cat sriov-eno2-pod.yaml | kubectl apply -f -

