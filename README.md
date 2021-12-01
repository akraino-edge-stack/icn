# Introduction
ICN strives to automate the process of installing the local cluster
controller to the greatest degree possible – "zero touch
installation". Once the jump server (Local Controller) is booted and
the compute cluster-specific values are provided, the controller is
begins to inspect and provision the bare metal servers until the
cluster is entirely configured. This document shows step-by-step how
to configure the network and deployment architecture for the ICN
blueprint.

# License
Apache license v2.0

# Deployment Architecture
The Local Controller is provisioned with the Cluster API controllers
and the Metal3 infrastructure provider, which enable provisioning of
bare metal servers. The controller has three network connections to
the bare metal servers: network A connects bare metal servers, network
B is a private network used for provisioning the bare metal servers
and network C is the IPMI network, used for control during
provisioning. In addition, the bare metal servers connect to the
network D, the SRIOV network.

![Figure 1](figure-1.png)*Figure 1: Deployment Architecture*

- Net A -- Bare metal network, lab networking for ssh. It is used as
  the control plane for K8s, used by OVN and Flannel for the overlay
  networking.
- Net B (internal network) -- Provisioning network used by Ironic to
  do inspection.
- Net C (internal network) -- IPMI LAN to do IPMI protocol for the OS
  provisioning. The NICs support IPMI. The IP address should be
  statically assigned via the IPMI tool or other means.
- Net D (internal network) -- Data plane network for the Akraino
  application. Using the SR-IOV networking and fiber cables.  Intel
  25GB and 40GB FLV NICs.

In some deployment models, you can combine Net C and Net A to be the
same networks, but the developer should take care of IP address
management between Net A and IPMI address of the server.

Also note that the IPMI NIC may share the same RJ-45 jack with another
one of the NICs.

# Pre-installation Requirements
There are two main components in ICN Infra Local Controller - Local
Controller and K8s compute cluster.

### Local Controller
The Local Controller will reside in the jump server to run the Cluster
API controllers with the Kubeadm bootstrap provider and Metal3
infrastructure provider.

### K8s Compute Cluster
The K8s compute cluster will actually run the workloads and is
installed on bare metal servers.

## Hardware Requirements

### Minimum Hardware Requirement
All-in-one VM based deployment requires servers with at least 32 GB
RAM and 32 CPUs.

### Recommended Hardware Requirements
Recommended hardware requirements are servers with 64GB Memory, 32
CPUs and SRIOV network cards.

## Software Prerequisites
The jump server is required to be pre-installed with Ubuntu 18.04.

## Database Prerequisites
No prerequisites for ICN blueprint.

## Other Installation Requirements

### Jump Server Requirements

#### Jump Server Hardware Requirements
- Local Controller: at least three network interfaces.
- Bare metal servers: four network interfaces, including one IPMI interface.
- Four or more hubs, with cabling, to connect four networks.

(Tested as below)
Hostname | CPU Model | Memory | Storage | 1GbE: NIC#, VLAN, (Connected extreme 480 switch) | 10GbE: NIC# VLAN, Network (Connected with IZ1 switch)
---------|-----------|--------|---------|--------------------------------------------------|------------------------------------------------------
jump0 | Intel 2xE5-2699 | 64GB | 3TB (Sata)<br/>180 (SSD) | eth0: VLAN 110<br/>eno1: VLAN 110<br/>eno2: VLAN 111 |

#### Jump Server Software Requirements
ICN supports Ubuntu 18.04. The ICN blueprint installs all required
software during `make jump_server`.

### Network Requirements
Please refer to figure 1 for all the network requirements of the ICN
blueprint.

Please make sure you have 3 distinguished networks - Net A, Net B and
Net C as mentioned in figure 1. Local Controller uses the Net B and
Net C to provision the bare metal servers to do the OS provisioning.

### Bare Metal Server Requirements

### K8s Compute Cluster

#### Compute Server Hardware Requirements
(Tested as below)
Hostname | CPU Model | Memory | Storage | 1GbE: NIC#, VLAN, (Connected extreme 480 switch) | 10GbE: NIC# VLAN, Network (Connected with IZ1 switch)
---------|-----------|--------|---------|--------------------------------------------------|------------------------------------------------------
node1 | Intel 2xE5-2699 | 64GB | 3TB (Sata)<br/>180 (SSD) | eth0: VLAN 110<br/>eno1: VLAN 110<br/>eno2: VLAN 111 | eno3: VLAN 113
node2 | Intel 2xE5-2699 | 64GB | 3TB (Sata)<br/>180 (SSD) | eth0: VLAN 110<br/>eno1: VLAN 110<br/>eno2: VLAN 111 | eno3: VLAN 113
node3 | Intel 2xE5-2699 | 64GB | 3TB (Sata)<br/>180 (SSD) | eth0: VLAN 110<br/>eno1: VLAN 110<br/>eno2: VLAN 111 | eno3: VLAN 113

#### Compute Server Software Requirements
The Local Controller will install all the software in compute servers
from the OS to the software required to bring up the K8s cluster.

### Execution Requirements (Bare Metal Only)
The ICN blueprint checks all the precondition and execution
requirements for bare metal.

# Installation High-Level Overview
Installation is two-step process:
- Installation of the Local Controller.
- Installation of a compute cluster.

## Bare Metal Deployment Guide

### Install Bare Metal Jump Server

#### Creating the Settings Files

##### Local Controller Network Configuration Reference
The user will find the network configuration file named as
"user_config.sh" in the ICN parent directory.

`user_config.sh`
``` shell
#!/bin/bash

#Ironic Metal3 settings for provisioning network (Net B)
export IRONIC_INTERFACE="eno2"

#Ironic Metal3 setting for IPMI LAN Network (Net C)
export IRONIC_IPMI_INTERFACE="eno1"
```

#### Running
After configuring the network configuration file, please run `make
jump_server` from the ICN parent directory as shown below:

``` shell
root@jump0:# git clone "https://gerrit.akraino.org/r/icn"
Cloning into 'icn'...
remote: Counting objects: 69, done
remote: Finding sources: 100% (69/69)
remote: Total 4248 (delta 13), reused 4221 (delta 13)
Receiving objects: 100% (4248/4248), 7.74 MiB | 21.84 MiB/s, done.
Resolving deltas: 100% (1078/1078), done.
root@jump0:# cd icn/
root@jump0:# make jump_server
```

The following steps occurs once the `make jump_server` command is
given.
1. All the software required to run the bootstrap cluster is
   downloaded and installed.
2. K8s cluster to maintain the bootstrap cluster and all the servers
   in the edge location is installed.
3. Metal3 specific network configuration such as local DHCP server
   networking for each edge location, Ironic networking for both
   provisioning network and IPMI LAN network are identified and
   created.
4. The Cluster API controllers, bootstrap, and infrastructure
   providers and configured and installed.
5. The Flux controllers are installed.

#### Creating a compute cluster
A compute cluster is composed of installations of two types of Helm
charts: machine and cluster. The specific installations of these Helm
charts are defined in HelmRelease resources consumed by the Flux
controllers in the jump server. The user is required to provide the
machine and cluster specific values in the HelmRelease resources.

##### Preconfiguration for the compute cluster in Jump Server
The user is required to provide the IPMI information of the servers
and the values of the compute cluster they connect to the Local
Controller.

If the baremetal network provides a DHCP server with gateway and DNS
server information, and each server has identical hardware then a
cluster template can be used. Otherwise these values must also be
provided with the values for each server. Refer to the machine chart
in icn/deploy/machine for more details. In the example below, no DHCP
server is present in the baremetal network.

`site.yaml`
``` yaml
apiVersion: v1
kind: Namespace
metadata:
    name: metal3
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
    name: machine-node1
    namespace: metal3
spec:
    interval: 5m
    chart:
        spec:
            chart: deploy/machine
            sourceRef:
                kind: GitRepository
                name: icn
                namespace: flux-system
            interval: 1m
    values:
        machineName: node1
        machineLabels:
            machine: node1
        bmcAddress: ipmi://10.10.110.11
        bmcUsername: admin
        bmcPassword: password
        networks:
            baremetal:
                macAddress: 00:1e:67:fe:f4:19
                type: ipv4
                ipAddress: 10.10.110.21/24
                gateway: 10.10.110.1
                nameservers: ["8.8.8.8"]
            provisioning:
                macAddress: 00:1e:67:fe:f4:1a
                type: ipv4_dhcp
            sriov:
                macAddress: 00:1e:67:f8:6a:41
                type: ipv4
                ipAddress: 10.10.113.3/24
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
    name: machine-node2
    namespace: metal3
spec:
    interval: 5m
    chart:
        spec:
            chart: deploy/machine
            sourceRef:
                kind: GitRepository
                name: icn
                namespace: flux-system
            interval: 1m
    values:
        machineName: node2
        machineLabels:
            machine: node2
        bmcAddress: ipmi://10.10.110.12
        bmcUsername: admin
        bmcPassword: password
        networks:
            baremetal:
                macAddress: 00:1e:67:f1:5b:90
                type: ipv4
                ipAddress: 10.10.110.22/24
                gateway: 10.10.110.1
                nameservers: ["8.8.8.8"]
            provisioning:
                macAddress: 00:1e:67:f1:5b:91
                type: ipv4_dhcp
            sriov:
                macAddress: 00:1e:67:f8:69:81
                type: ipv4
                ipAddress: 10.10.113.4/24
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
    name: cluster-compute
    namespace: metal3
spec:
    interval: 5m
    chart:
        spec:
            chart: deploy/cluster
            sourceRef:
                kind: GitRepository
                name: icn
                namespace: flux-system
            interval: 1m
    values:
        clusterName: compute
        controlPlaneEndpoint: 10.10.110.21
        controlPlaneHostSelector:
            matchLabels:
                machine: node1
        workersHostSelector:
            matchLabels:
                machine: node2
        userData:
            hashedPassword: $6$rounds=10000$PJLOBdyTv23pNp$9RpaAOcibbXUMvgJScKK2JRQioXW4XAVFMRKqgCB5jC4QmtAdbA70DU2jTcpAd6pRdEZIaWFjLCNQMBmiiL40.
            sshAuthorizedKey: ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCrxu+fSrU51vgAO5zP5xWcTU8uLv4MkUZptE2m1BJE88JdQ80kz9DmUmq2AniMkVTy4pNeUW5PsmGJa+anN3MPM99CR9I37zRqy5i6rUDQgKjz8W12RauyeRMIBrbdy7AX1xasoTRnd6Ta47bP0egiFb+vUGnlTFhgfrbYfjbkJhVfVLCTgRw8Yj0NSK16YEyhYLbLXpix5udRpXSiFYIyAEWRCCsWJWljACr99P7EF82vCGI0UDGCCd/1upbUwZeTouD/FJBw9qppe6/1eaqRp7D36UYe3KzLpfHQNgm9AzwgYYZrD4tNN6QBMq/VUIuam0G1aLgG8IYRLs41HYkJ root@jump0
        flux:
            url: https://gerrit.akraino.org/r/icn
            branch: master
            path: ./deploy/site/cluster-e2etest
```

A brief overview of the values is below. Refer to the machine and
cluster charts in deploy/machine and deploy/cluster respectively for
more details.

- *machineName*: This will be the hostname for the machine, once it is
  provisioned by Metal3.
- *bmcUsername*: BMC username required to be provided for Ironic.
- *bmcPassword*: BMC password required to be provided for Ironic.
- *bmcAddress*: BMC server IPMI LAN IP address.
- *networks*: A dictionary of the networks used by ICN.  For more
  information, refer to the *networkData* field of the BareMetalHost
  resource definition.
  - *macAddress*: The MAC address of the interface.
  - *type*: The type of network, either dynamic ("ipv4_dhcp") or
    static ("ipv4").
  - *ipAddress*: Only valid for type "ipv4"; the IP address of the
    interface.
  - *gateway*: Only valid for type "ipv4"; the gateway of this
    network.
  - *nameservers*: Only valid for type "ipv4"; an array of DNS
     servers.
- *clusterName*: The name of the cluster.
- *controlPlaneEndpoint*: The K8s control plane endpoint. This works
  in cooperation with the *controlPlaneHostSelector* to ensure that it
  addresses the control plane node.
- *controlPlaneHostSelector*: A K8s match expression against labels on
  the *BareMetalHost* machine resource (from the *machineLabels* value
  of the machine Helm chart).  This will be used by Cluster API to
  select machines for the control plane.
- *workersHostSelector*: A K8s match expression selecting worker
  machines.
- *userData*: User data values to be provisioned into each machine in
  the cluster.
  - *hashedPassword*: The hashed password of the default user on each
    machine.
  - *sshAuthorizedKey*: An authorized public key of the *root* user on
    each machine.
- *flux*: An optional repository to continuously reconcile the created
  K8s cluster against.

#### Running
After configuring the machine and cluster site values, the next steps
are to encrypt the secrets contained in the file, commit the file to
source control, and create the Flux resources on the jump server
pointing to the committed files.

1. Create a key protect the secrets in the values if one does not
   already exist. The key created below will be named "site-secrets".

``` shell
root@jump0:# ./deploy/site/site.sh create-gpg-key site-secrets
```

2. Encrypt the secrets in the site values.

``` shell
root@jump0:# ./deploy/site/site.sh sops-encrypt-site site.yaml site-secrets
```

3. Commit the site.yaml and additional files (sops.pub.asc,
   .sops.yaml) created by sops-encrypt-site to a Git repository. For
   the purposes of the next step, site.yaml will be committed to a Git
   repository hosted at URL, on the specified BRANCH, and at location
   PATH inside the source tree.

4. Create the Flux resources to deploy the resources described by the
   repository in step 3. This creates a GitRepository resource
   containing the URL and BRANCH to synchronize, a Secret resource
   containing the private key used to decrypt the secrets in the site
   values, and a Kustomization resource with the PATH to the site.yaml
   file at the GitRepository.

```shell
root@jump0:# ./deploy/site/site.sh flux-create-site URL BRANCH PATH site-secrets
```

The progress of the deployment may be monitored in a number of ways:

``` shell
root@jump0:# kubectl -n metal3 get baremetalhost
root@jump0:# kubectl -n metal3 get cluster compute
root@jump0:# clusterctl -n metal3 describe cluster compute
```

When the control plane is ready, the kubeconfig can be obtained with
clusterctl and used to access the compute cluster:

``` shell
root@jump0:# clusterctl -n metal3 get kubeconfig compute >compute-admin.conf
root@jump0:# kubectl --kubeconfig=compute-admin.conf cluster-info
```

## Virtual Deployment Guide

### Standard Deployment Overview
![Figure 2](figure-2.png)*Figure 2: Virtual Deployment Architecture*

Virtual deployment is used for the development environment using
Vagrant to create VMs with PXE boot. No setting is required from the
user to deploy the virtual deployment.

### Snapshot Deployment Overview
No snapshot is implemented in ICN R6.

### Special Requirements for Virtual Deployment

#### Install Jump Server
Jump server is required to be installed with Ubuntu 18.04. This will
install all the VMs and install the K8s clusters.

#### Verifying the Setup - VMs
To verify the virtual deployment, execute the following commands:
``` shell
$ vagrant up --no-parallel
$ vagrant ssh jump
vagrant@jump:~$ sudo su
root@jump:/home/vagrant# cd /icn
root@jump:/icn# make jump_server
root@jump:/icn# make vm_cluster
```
`vagrant up --no-parallel` creates three VMs: vm-jump, vm-machine-1,
and vm-machine-2, each with 16GB RAM and 8 vCPUs. `make jump_server`
installs the jump server components into vm-jump, and `make
vm_cluster` installs a K8s cluster on the vm-machine VMs using Cluster
API. The cluster is configured to use Flux to bring up the cluster
with all addons and plugins.

# Verifying the Setup
ICN blueprint checks all the setup in both bare metal and VM
deployment. Verify script will first confirm that the cluster control
plane is ready then run self tests of all addons and plugins.

**Bare Metal Verifier**: Run the `make bm_verifer`, it will verify the
bare-metal deployment.

**Verifier**: Run the `make vm_verifier`, it will verify the virtual
deployment.

# Developer Guide and Troubleshooting
For development uses the virtual deployment, it take up to 10 mins to
bring up the virtual BMC VMs with PXE boot.

## Utilization of Images
No images provided in this ICN release.

## Post-deployment Configuration
No post-deployment configuration required in this ICN release.

## Debugging Failures
* For first time installation enable KVM console in the trial or lab
  servers using Raritan console or use Intel web BMC console.

  ![Figure 3](figure-3.png)
* Deprovision state will result in Ironic agent sleeping before next
  heartbeat - it is not an error. It results in bare metal server
  without OS and installed with ramdisk.
* Deprovision in Metal3 is not straight forward - Metal3 follows
  various stages from provisioned, deprovisioning and ready. ICN
  blueprint take care navigating the deprovisioning states and
  removing the BareMetalHost (BMH) custom resouce in case of cleaning.
* Manual BMH cleaning of BMH or force cleaning of BMH resource result
  in hang state - use `make bmh_clean` to remove the BMH state.
* Logs of Ironic, openstack baremetal command to see the state of the
  server.
* Logs of baremetal operator gives failure related to images or images
  md5sum errors.
* It is not possible to change the state from provision to deprovision
  or deprovision to provision without completing that state. All the
  issues are handled in ICN scripts.

## Reporting a Bug
Required Linux Foundation ID to launch bug in ICN:
https://jira.akraino.org/projects/ICN/issues

# Uninstall Guide

## Bare Metal deployment
The command `make clean_all` uninstalls all the components installed by
`make install`
* It de-provision all the servers provisioned and removes them from
  Ironic database.
* Baremetal operator is deleted followed by Ironic database and
  container.
* Network configuration such internal DHCP server, provisioning
  interfaces and IPMI LAN interfaces are deleted.
* It will reset the bootstrap cluster - K8s cluster is torn down in
  the jump server and all the associated docker images are removed.
* All software packages installed by `make jump_server` are removed,
  such as Ironic, openstack utility tool, docker packages and basic
  prerequisite packages.

## Virtual deployment
The command `vagrant destroy -f` uninstalls all the components for the
virtual deployments.

# Troubleshooting

## Error Message Guide
The error message is explicit, all messages are captured in log
directory.

# Maintenance

## Blueprint Package Maintenance
No packages are maintained in ICN.

## Software maintenance
Not applicable.

## Hardware maintenance
Not applicable.

## BluePrint Deployment Maintenance
Not applicable.

# Frequently Asked Questions
**How to setup IPMI?**

First, make sure the IPMI tool is installed in your servers, if not
install them using `apt install ipmitool`. Then, check for the
ipmitool information of each servers using the command `ipmitool lan
print 1`. If the above command doesn't show the IPMI information, then
setup the IPMI static IP address using the following instructions:
- Mostl easy way to set up IPMI topology in your lab setup is by
  using IPMI tool.
- Using IPMI tool -
  https://www.thomas-krenn.com/en/wiki/Configuring_IPMI_under_Linux_using_ipmitool
- IPMI information can be considered during the BIOS setting as well.

**BMC web console URL is not working?**

It is hard to find issues or reason. Check the ipmitool bmc info to
find the issues, if the URL is not available.

**No change in BMH state - provisioning state is for more than 40min?**

Generally, Metal3 provision for bare metal takes 20 - 30 mins. Look at
the Ironic logs and baremetal operator to look at the state of
servers. Openstack baremetal node shows all state of the server right
from power, storage.

**Why provider network (baremetal network configuration) is required?**

Generally, provider network DHCP servers in a lab provide the router
and DNS server details. In some labs, there is no DHCP server or the
DHCP server does not provide this information.

# License

```
/*
* Copyright 2019 Intel Corporation, Inc
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/
```

# References

# Definitions, acronyms and abbreviations
