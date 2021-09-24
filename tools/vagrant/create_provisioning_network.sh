#!/bin/bash
set -eu -o pipefail

site=$1

if virsh -c qemu:///system net-info ${site}-provisioning >/dev/null 2>&1; then
    echo provisioning network is already created
else
    cat <<EOF >${site}-provisioning-network.xml
<network>
  <name>${site}-provisioning</name>
  <bridge name="${site}0"/>
</network>
EOF
    virsh -c qemu:///system net-define ${site}-provisioning-network.xml
    virsh -c qemu:///system net-start ${site}-provisioning
fi
