#!/bin/bash
set -eu -o pipefail

site=$1			# vm
gateway4=$2		# 192.168.151.1
netmask=$3		# 255.255.255.0
gateway6=${4:-""}	# fd9c:05f4:ea84:0::1
prefix=${5:-"64"}	# 64

if virsh -c qemu:///system net-info ${site}-baremetal >/dev/null 2>&1; then
    echo baremetal network is already created
else
    cat <<EOF >${site}-baremetal-network.xml
<network>
  <name>${site}-baremetal</name>
  <forward mode="nat">
    <nat>
      <port start="1024" end="65535"/>
    </nat>
  </forward>
  <bridge name="${site}0"/>
  <ip address="${gateway4}" netmask="${netmask}"/>
EOF
    if [[ ! -z ${gateway6} ]]; then
	cat <<EOF >>${site}-baremetal-network.xml
  <ip family="ipv6" address="${gateway6}" prefix="${prefix}"/>
EOF
    fi
    cat <<EOF >>${site}-baremetal-network.xml
</network>
EOF
    virsh -c qemu:///system net-define ${site}-baremetal-network.xml
    virsh -c qemu:///system net-start ${site}-baremetal
fi
