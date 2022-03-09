#!/bin/bash -l
echo "---> vagrant-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

function clean_vm {{
    ./tools/vagrant/destroy.rb
}}
trap clean_vm EXIT

# TODO Improve VM performance by only using cores on the same node
#sed -i -e '/^\s\+libvirt.cpus/!b' -e "h;s/\S.*/libvirt.cpuset = '0-21,44-65'/;H;g" Vagrantfile

./tools/vagrant/destroy.rb
vagrant up --no-parallel
vagrant ssh jump -c "
set -exuf
cd /icn
sudo su -c 'make {target}'
"
