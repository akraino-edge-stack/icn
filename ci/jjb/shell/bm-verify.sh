#!/bin/bash -l
echo "---> bm-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

sudo apt update
sudo apt install -y make
sudo su -c 'make {target}'
