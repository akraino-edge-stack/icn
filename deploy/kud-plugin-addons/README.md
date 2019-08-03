kud-plugin-addons provides the scripts and yaml files to install kud-addons on working node which includes: device plugins, nfd, prometheus, rook etc.
1. device plugin:
(1) driver: include scripts to install driver on working node
collect_XX.sh: invoked by collect.sh in build machine to generate the driver installation package (e.g. qat_driver-0.1.tar.gz etc.), the package will be installed on /opt/icn/driver in icn infra-local-controller. BPA can install this package on cluster node, then install the driver with below commands:
$ tar xzvf qat_driver-0.1.tar.gz
$ cd qat_driver
$ bash install.sh

(2) yaml: include the yaml file to install k8s device plugin
collect_XX.sh: invoked by collect.sh in build machine to generate the k8s device plugin installation package (e.g. qat_yaml-0.1.tar.gz etc.), the package will be installed on /opt/icn/yaml in icn infra-local-controller. BPA can install this package on cluster node, then install the device plugin with below commands(it assumed that k8s cluster had been installed by kud):
$ tar xzvf qat_yaml-0.1.tar.gz
$ cd qat_yaml
$ bash install.sh

(3) test: include the test yaml file with sample workloads to use the device plugin 

2. nfd
3. prometheus
4. rook

