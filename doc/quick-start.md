# Quick start

To get a taste of ICN, this guide will walk through creating a simple
two machine cluster using virtual machines.

A total of 3 virtual machines will be used: each with 8 CPUs, 24 GB
RAM, and 30 GB disk. So grab a host machine, [install Vagrant with the
libvirt provider](https://github.com/vagrant-libvirt/vagrant-libvirt#installation), and let's get started.

TL;DR

    $ git clone https://gerrit.akraino.org/r/icn
    $ cd icn
    $ vagrant up --no-parallel
    $ vagrant ssh jump
    vagrant@jump:~$ sudo su
    root@jump:/home/vagrant# cd /icn
    root@jump:/icn# make jump_server
    root@jump:/icn# make vm_cluster

> NOTE: vagrant destroy may fail due to
> https://github.com/vagrant-libvirt/vagrant-libvirt/issues/1371. The
> workaround is to destroy the machines manually
>
>     $ virsh -c qemu:///system destroy vm-machine-1
>     $ virsh -c qemu:///system undefine --nvram --remove-all-storage vm-machine-1
>     $ virsh -c qemu:///system destroy vm-machine-2
>     $ virsh -c qemu:///system undefine --nvram --remove-all-storage vm-machine-2

## Create the virtual environment

    $ vagrant up --no-parallel

Now let's take a closer look at what was created.

    $ virsh -c qemu:///system list
     Id    Name                           State
    ----------------------------------------------------
     1207  vm-jump                        running
     1208  vm-machine-1                   running
     1209  vm-machine-2                   running

    $ virsh -c qemu:///system net-list
     Name                 State      Autostart     Persistent
    ----------------------------------------------------------
     vm-baremetal         active     yes           yes
     vm-provisioning      active     no            yes

    $ vbmc list
    +--------------+---------+---------+------+
    | Domain name  | Status  | Address | Port |
    +--------------+---------+---------+------+
    | vm-machine-1 | running | ::      | 6230 |
    | vm-machine-2 | running | ::      | 6231 |
    +--------------+---------+---------+------+

We've created a jump server and the two machines that will form the
cluster. The jump server will be responsible for creating the
cluster.

We also created two networks, baremetal and provisioning, and a third
network overlaid upon the baremetal network using [VirtualBMC](https://opendev.org/openstack/virtualbmc) for
issuing IPMI commands to the virtual machines.

It's worth looking at these networks in more detail as they will be
important during configuration of the jump server and cluster.

    $ virsh -c qemu:///system net-dumpxml vm-baremetal
    <network connections='3' ipv6='yes'>
      <name>vm-baremetal</name>
      <uuid>216db810-de49-4122-a284-13fd2e44da4b</uuid>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='virbr3' stp='on' delay='0'/>
      <mac address='52:54:00:a3:e7:09'/>
      <ip address='192.168.151.1' netmask='255.255.255.0'>
        <dhcp>
          <range start='192.168.151.1' end='192.168.151.254'/>
        </dhcp>
      </ip>
    </network>

The baremetal network provides outbound network access through the
host and also assigns DHCP addresses in the range `192.168.151.2` to
`192.168.151.254` to the virtual machines (the host itself is
`192.168.151.1`).

    $ virsh -c qemu:///system net-dumpxml vm-provisioning
    <network connections='3'>
      <name>vm-provisioning</name>
      <uuid>d06de3cc-b7ca-4b09-a49d-a1458c45e072</uuid>
      <bridge name='vm0' stp='on' delay='0'/>
      <mac address='52:54:00:3e:38:a5'/>
    </network>

The provisioning network is a private network; only the virtual
machines may communicate over it. Importantly, no DHCP server is
present on this network. The `ironic` component of the jump server will
be managing DHCP requests.

The virtual baseband management controller controllers provided by
VirtualBMC are listening at the address and port listed above on the
host. To issue an IPMI command to `vm-machine-1` for example, the
command will be issued to `192.168.151.1:6230`, and VirtualBMC will
translate the the IPMI command into libvirt calls.

Now let's look at the networks from inside the virtual machines.

    $ virsh -c qemu:///system dumpxml vm-jump
    ...
        <interface type='network'>
          <mac address='52:54:00:a8:97:6d'/>
          <source network='vm-baremetal' bridge='virbr3'/>
          <target dev='vnet0'/>
          <model type='virtio'/>
          <alias name='ua-net-0'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
        </interface>
        <interface type='network'>
          <mac address='52:54:00:80:3d:4c'/>
          <source network='vm-provisioning' bridge='vm0'/>
          <target dev='vnet1'/>
          <model type='virtio'/>
          <alias name='ua-net-1'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
        </interface>
    ...

The baremetal network NIC in the jump server is the first NIC present
in the machine and depending on the device naming scheme in place will
be called `ens5` or `eth0`. Similarly, the provisioning network NIC will
be `ens6` or `eth1`.

    $ virsh -c qemu:///system dumpxml vm-machine-1
    ...
        <interface type='network'>
          <mac address='52:54:00:c6:75:40'/>
          <source network='vm-provisioning' bridge='vm0'/>
          <target dev='vnet2'/>
          <model type='virtio'/>
          <alias name='ua-net-0'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
        </interface>
        <interface type='network'>
          <mac address='52:54:00:20:a3:0a'/>
          <source network='vm-baremetal' bridge='virbr3'/>
          <target dev='vnet4'/>
          <model type='virtio'/>
          <alias name='ua-net-1'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
        </interface>
    ...

In contrast to the jump server, the provisioning network NIC is the
first NIC present in the machine and will be named `ens5` or `eth0` and
the baremetal network NIC will be `ens6` or `eth1`.

The order of NICs is crucial here: the provisioning network NIC must
be the NIC that the machine PXE boots from, and the BIOS used in this
virtual machine is configured to use the first NIC in the machine. A
physical machine will typically provide this as a configuration option
in the BIOS settings.


## Install the jump server components

    $ vagrant ssh jump
    vagrant@jump:~$ sudo su
    root@jump:/home/vagrant# cd /icn

Before telling ICN to start installing the components, it must first
know which is the IPMI network NIC and which is the provisioning
network NIC. Recall that in the jump server the IPMI network is
overlaid onto the baremetal network and that the baremetal network NIC
is `eth0`, and also that the provisioning network NIC is `eth1`.

Edit `user_config.sh` to the below.

    #!/usr/bin/env bash
    export IRONIC_INTERFACE="eth1"

Now install the jump server components.

    root@jump:/icn# make jump_server

Let's walk quickly through some of the components installed. The
first, and most fundamental, is that the jump server is now a
single-node Kubernetes cluster.

    root@jump:/icn# kubectl cluster-info
    Kubernetes control plane is running at https://192.168.151.45:6443
    
    To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

The next is that [Cluster API](https://cluster-api.sigs.k8s.io/) is installed, with the [Metal3](https://github.com/metal3-io/cluster-api-provider-metal3)
infrastructure provider and Kubeadm bootstrap provider. These
components provide the base for creating clusters with ICN.

    root@jump:/icn# kubectl get deployments -A
    NAMESPACE                           NAME                                            READY   UP-TO-DATE   AVAILABLE   AGE
    baremetal-operator-system           baremetal-operator-controller-manager           1/1     1            1           96m
    capi-kubeadm-bootstrap-system       capi-kubeadm-bootstrap-controller-manager       1/1     1            1           96m
    capi-kubeadm-control-plane-system   capi-kubeadm-control-plane-controller-manager   1/1     1            1           96m
    capi-system                         capi-controller-manager                         1/1     1            1           96m
    capm3-system                        capm3-controller-manager                        1/1     1            1           96m
    capm3-system                        capm3-ironic                                    1/1     1            1           98m
    capm3-system                        ipam-controller-manager                         1/1     1            1           96m
    ...

A closer look at the above deployments shows two others of interest:
`baremetal-operator-controller-manager` and `capm3-ironic`. These
components are from the [Metal3](https://metal3.io/) project and are dependencies of the
Metal3 infrastructure provider.

Before moving on to the next step, let's take one last look at the
provisioning NIC we set in `user_config.sh`.

    root@jump:/icn# ip link show dev eth1
    3: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master provisioning state UP mode DEFAULT group default qlen 1000
        link/ether 52:54:00:80:3d:4c brd ff:ff:ff:ff:ff:ff

The `master provisioning` portion indicates that this interface is now
attached to the `provisioning` bridge. The `provisioning` bridge was
created during installation and is how the `capm3-ironic` deployment
will communicate with the machines to be provisioned when it is time
to install an operating system.


## Create a cluster

    root@jump:/icn# make vm_cluster

Once complete, we'll have a K8s cluster up and running on the machines
created earlier with all of the ICN addons configured and validated.

    root@jump:/icn# clusterctl -n metal3 describe cluster icn
    NAME                                                                READY  SEVERITY  REASON  SINCE  MESSAGE
    /icn                                                                True                     81m
    ├─ClusterInfrastructure - Metal3Cluster/icn
    ├─ControlPlane - KubeadmControlPlane/icn                            True                     81m
    │ └─Machine/icn-qhg4r                                               True                     81m
    │   └─MachineInfrastructure - Metal3Machine/icn-controlplane-r8g2f
    └─Workers
      └─MachineDeployment/icn                                           True                     73m
        └─Machine/icn-6b8dfc7f6f-qvrqv                                  True                     76m
          └─MachineInfrastructure - Metal3Machine/icn-workers-bxf52

    root@jump:/icn# clusterctl -n metal3 get kubeconfig icn >icn-admin.conf
    root@jump:/icn# kubectl --kubeconfig=icn-admin.conf cluster-info
    Kubernetes control plane is running at https://192.168.151.254:6443
    CoreDNS is running at https://192.168.151.254:6443/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
    
    To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.


## Next steps

At this point you may proceed with the [Installation
guide](installation-guide.md) to learn more about the hardware and
software configuration in a physical environment or jump directly to
the [Deployment](installation-guide.md#Deployment) sub-section to
examine the cluster creation process in more detail.


<a id="org48e2dc9"></a>

