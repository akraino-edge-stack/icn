#!/bin/bash
set -eu -o pipefail

num_machines=$1
site=$2
name_prefix=$3

nodes_json_path="deploy/metal3/scripts/nodes.json.sample"
ipmi_host=$(virsh -c qemu:///system net-dumpxml ${site}-baremetal | xmlstarlet sel -t -v "//network/ip/@address")

cat <<EOF >${nodes_json_path}
{
  "nodes": [
EOF
for ((i=1;i<=num_machines;++i)); do
    name="${name_prefix}${i}"
    ipmi_port=$((6230+i-1))
    baremetal_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-baremetal']/mac/@address")
    provisioning_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-provisioning']/mac/@address")
    if ((i<num_machines)); then comma=","; else comma=""; fi
    cat <<EOF >>${nodes_json_path}
    {
      "name": "${name}",
      "ipmi_driver_info": {
        "username": "admin",
        "password": "password",
        "address": "${ipmi_host}:${ipmi_port}"
      },
      "os": {
        "image_name": "focal-server-cloudimg-amd64.img",
        "username": "ubuntu",
        "password": "mypasswd"
      },
      "net": {
        "links": [
          {
            "id": "baremetal_nic",
            "ethernet_mac_address": "${baremetal_mac}",
            "type": "phy"
          },
          {
            "id": "provisioning_nic",
            "ethernet_mac_address": "${provisioning_mac}",
            "type": "phy"
          }
        ],
        "networks": [
          {
            "id": "baremetal",
            "link": "baremetal_nic",
            "type": "ipv4_dhcp"
          },
          {
            "id": "provisioning",
            "link": "provisioning_nic",
            "type": "ipv4_dhcp"
          }
        ],
        "services": []
      }
    }${comma}
EOF
done
cat <<EOF >>${nodes_json_path}
  ]
}
EOF
