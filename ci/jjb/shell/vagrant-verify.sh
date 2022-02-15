#!/bin/bash -l
echo "---> vagrant-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

function clean_vm {{
    # TODO Vagrant has a known issue
    # (https://github.com/vagrant-libvirt/vagrant-libvirt/issues/1371)
    # destroying the VMs, so destroy them manually here
    vagrant destroy -f jump
    virsh -c qemu:///system destroy vm-machine-1
    virsh -c qemu:///system undefine --nvram --remove-all-storage vm-machine-1
    virsh -c qemu:///system destroy vm-machine-2
    virsh -c qemu:///system undefine --nvram --remove-all-storage vm-machine-2
}}
trap clean_vm EXIT

# TODO Improve VM performance by only using cores on the same node
#sed -i -e '/^\s\+libvirt.cpus/!b' -e "h;s/\S.*/libvirt.cpuset = '0-21,44-65'/;H;g" Vagrantfile

vagrant destroy -f
vagrant up --no-parallel
vagrant ssh jump -c "
set -exuf
cd /icn
sudo su -c 'make {target}'
"
