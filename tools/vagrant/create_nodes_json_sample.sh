#!/bin/bash
set -eu -o pipefail

site=$1; shift

nodes_json_path="deploy/metal3/scripts/nodes.json.sample"
ipmi_host=$(virsh -c qemu:///system net-dumpxml ${site}-baremetal | xmlstarlet sel -t -v "//network/ip/@address")

cat <<EOF >${nodes_json_path}
{
  "nodes": [
EOF

while (("$#")); do
    name=$1; shift
    ipmi_port=$1; shift
    baremetal_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-baremetal']/mac/@address")
    provisioning_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-provisioning']/mac/@address")
    if (("$#")); then comma=","; else comma=""; fi
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
