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

    $ virsh -c qemu:///system list --uuid --name
    0582a3ab-2516-47fe-8a77-2a88c411b550 vm-jump
    ab389bad-2f4a-4eba-b49e-0d649ff3d237 vm-machine-1
    8d747997-dcd1-42ca-9e25-b3eedbe326aa vm-machine-2

    $ virsh -c qemu:///system net-list
     Name                 State      Autostart     Persistent
    ----------------------------------------------------------
     vagrant-libvirt      active     no            yes
     vm-baremetal         active     no            yes
     vm-provisioning      active     no            yes

    $ curl --insecure -u admin:password https://192.168.121.1:8000/redfish/v1/Managers
    {
        "@odata.type": "#ManagerCollection.ManagerCollection",
        "Name": "Manager Collection",
        "Members@odata.count": 3,
        "Members": [
    
              {
                  "@odata.id": "/redfish/v1/Managers/0582a3ab-2516-47fe-8a77-2a88c411b550"
              },
    
              {
                  "@odata.id": "/redfish/v1/Managers/8d747997-dcd1-42ca-9e25-b3eedbe326aa"
              },
    
              {
                  "@odata.id": "/redfish/v1/Managers/ab389bad-2f4a-4eba-b49e-0d649ff3d237"
              }
    
        ],
        "Oem": {},
        "@odata.context": "/redfish/v1/$metadata#ManagerCollection.ManagerCollection",
        "@odata.id": "/redfish/v1/Managers",
        "@Redfish.Copyright": "Copyright 2014-2017 Distributed Management Task Force, Inc. (DMTF). For the full DMTF copyright policy, see http://www.dmtf.org/about/policies/copyright."
    }

We've created a jump server and the two machines that will form the
cluster. The jump server will be responsible for creating the
cluster.

We also created two networks, baremetal and provisioning. The [Virtual
Redfish
BMC](https://docs.openstack.org/sushy-tools/latest/user/dynamic-emulator.html)
used for issuing Redfish requests to the virtual machines is overlaid
on the vagrant-libvirt network.

It's worth looking at these networks in more detail as they will be
important during configuration of the jump server and cluster.

    $ virsh -c qemu:///system net-dumpxml vm-baremetal
    <network connections='3'>
      <name>vm-baremetal</name>
      <uuid>216db810-de49-4122-a284-13fd2e44da4b</uuid>
      <forward mode='nat'>
        <nat>
          <port start='1024' end='65535'/>
        </nat>
      </forward>
      <bridge name='vm0' stp='on' delay='0'/>
      <mac address='52:54:00:a3:e7:09'/>
      <ip address='192.168.151.1' netmask='255.255.255.0'>
      </ip>
    </network>

The baremetal network provides outbound network access through the
host. No DHCP server is present on this network. Address assignment to
the virtual machines is done using the (Metal3
IPAM)[https://metal3.io/blog/2020/07/06/IP_address_manager.html] while
the host itself is `192.168.151.1`.

    $ virsh -c qemu:///system net-dumpxml vm-provisioning
    <network connections='3'>
      <name>vm-provisioning</name>
      <uuid>d06de3cc-b7ca-4b09-a49d-a1458c45e072</uuid>
      <bridge name='vm1' stp='on' delay='0'/>
      <mac address='52:54:00:3e:38:a5'/>
    </network>

The provisioning network is a private network; only the virtual
machines may communicate over it. Importantly, no DHCP server is
present on this network. The `ironic` component of the jump server will
be managing DHCP requests.

The virtual baseband management controller provided by the Virtual
Redfish BMC is listening at the address and port listed in the curl
command above. To issue a Redfish request to `vm-machine-1` for
example, the request will be issued to `192.168.121.1:8000`, and the
Virtual Redfish BMC will translate the the request into libvirt calls.

Now let's look at the networks from inside the virtual machines.

    $ virsh -c qemu:///system dumpxml vm-jump
    ...
        <interface type='network'>
          <mac address='52:54:00:fc:a8:01'/>
          <source network='vagrant-libvirt' bridge='virbr1'/>
          <target dev='vnet0'/>
          <model type='virtio'/>
          <alias name='ua-net-0'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
        </interface>
        <interface type='network'>
          <mac address='52:54:00:a8:97:6d'/>
          <source network='vm-baremetal' bridge='vm0'/>
          <target dev='vnet1'/>
          <model type='virtio'/>
          <alias name='ua-net-1'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
        </interface>
        <interface type='network'>
          <mac address='52:54:00:80:3d:4c'/>
          <source network='vm-provisioning' bridge='vm1'/>
          <target dev='vnet2'/>
          <model type='virtio'/>
          <alias name='ua-net-2'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x07' function='0x0'/>
        </interface>
    ...

The baremetal network NIC in the jump server is the second NIC present
in the machine and depending on the device naming scheme in place will
be called `ens6` or `eth1`. Similarly, the provisioning network NIC will
be `ens7` or `eth2`.

    $ virsh -c qemu:///system dumpxml vm-machine-1
    ...
        <interface type='network'>
          <mac address='52:54:00:c6:75:40'/>
          <source network='vm-provisioning' bridge='vm1'/>
          <target dev='vnet3'/>
          <model type='virtio'/>
          <alias name='ua-net-0'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x05' function='0x0'/>
        </interface>
        <interface type='network'>
          <mac address='52:54:00:20:a3:0a'/>
          <source network='vm-baremetal' bridge='vm0'/>
          <target dev='vnet4'/>
          <model type='virtio'/>
          <alias name='ua-net-1'/>
          <address type='pci' domain='0x0000' bus='0x00' slot='0x06' function='0x0'/>
        </interface>
    ...

In contrast to the jump server, the provisioning network NIC is the
first NIC present in the machine and will be named `ens6` or `eth0` and
the baremetal network NIC will be `ens7` or `eth1`.

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
know which is the provisioning network NIC. Recall that in the jump
server the provisioning network NIC is `eth2`.

Edit `user_config.sh` to the below.

    #!/usr/bin/env bash
    export IRONIC_INTERFACE="eth2"

Now install the jump server components.

    root@jump:/icn# make jump_server

Let's walk quickly through some of the components installed. The
first, and most fundamental, is that the jump server is now a
single-node Kubernetes cluster.

    root@jump:/icn# kubectl cluster-info
    Kubernetes control plane is running at https://192.168.121.126:6443

    To further debug and diagnose cluster problems, use 'kubectl cluster-info dump'.

The next is that [Cluster API](https://cluster-api.sigs.k8s.io/) is
installed, with the
[Metal3](https://github.com/metal3-io/cluster-api-provider-metal3)
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

    root@jump:/icn# ip link show dev eth2
    4: eth2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel master provisioning state UP mode DEFAULT group default qlen 1000
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

