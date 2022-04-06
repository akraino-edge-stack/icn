#!/bin/bash
set -eu -o pipefail

site=$1

if virsh -c qemu:///system net-info ${site}-baremetal >/dev/null 2>&1; then
   virsh -c qemu:///system net-destroy ${site}-baremetal
   virsh -c qemu:///system net-undefine ${site}-baremetal
fi
