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
vagrant up --no-parallel
vagrant ssh jump -c "
set -exuf
cd /icn
sudo su -c 'make {target}'
"
