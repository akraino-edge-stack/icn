#!/bin/bash -l
echo "---> bm-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

sudo apt-get update
sudo apt-get install -y make
sudo su -c 'make {target}'
