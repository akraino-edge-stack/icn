#!/bin/bash -l
echo "---> verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail
vagrant destroy -f
vagrant up
vagrant ssh -c "
set -exuf
parted /dev/sda resizepart 3 yes 100%
resize2fs /dev/sda3
cd /vagrant
sudo apt update
sudo apt install -y make
sudo make verifier
"
