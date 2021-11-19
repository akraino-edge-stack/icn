#!/bin/bash
set -eu -o pipefail

index=$1
site=$2
name=$3

ipmi_host=$(virsh -c qemu:///system net-dumpxml ${site}-baremetal | xmlstarlet sel -t -v "//network/ip/@address")
ipmi_port=$((6230+index-1))
boot_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-provisioning']/mac/@address")

mkdir -p build/site/${site}
cat <<EOF >build/site/${site}/machine-${index}-values.yaml
machineName: machine-${index}
bootMACAddress: ${boot_mac}
bmcAddress: ipmi://${ipmi_host}:${ipmi_port}
bmcUsername: admin
bmcPassword: password
EOF
