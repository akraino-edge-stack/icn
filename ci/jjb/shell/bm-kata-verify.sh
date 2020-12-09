#!/bin/bash -l
echo "---> bm-verify.sh"

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -exuf -o pipefail

sed -i -e 's/CONTAINER_RUNTIME: "docker"/CONTAINER_RUNTIME: "containerd"/' cmd/bpa-operator/deploy/kud-installer.yaml
sudo apt update
sudo apt install -y make
sudo su -c 'make bm_verifer'
