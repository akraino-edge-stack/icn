#!/bin/bash -l
echo "---> vagrant-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

function clean_vm {{
    vagrant destroy -f
}}
trap clean_vm EXIT

vagrant destroy -f
vagrant up
vagrant ssh -c "
set -exuf
sudo parted -a optimal /dev/sda ---pretend-input-tty resizepart 3 yes 100%
sudo resize2fs /dev/sda3
sudo apt update
sudo apt install -y make
cd /vagrant
sudo su -c 'make {target}'
"
