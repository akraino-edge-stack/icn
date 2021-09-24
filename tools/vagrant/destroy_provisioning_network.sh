#!/bin/bash
set -eu -o pipefail

site=$1

if virsh -c qemu:///system net-info ${site}-provisioning >/dev/null 2>&1; then
   virsh -c qemu:///system net-destroy ${site}-provisioning
   virsh -c qemu:///system net-undefine ${site}-provisioning
fi
