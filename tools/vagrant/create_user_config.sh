#!/bin/bash
set -eu -o pipefail

cat <<EOF >user_config.sh
#!/usr/bin/env bash

#Ironic Metal3 settings for provisioning network
export IRONIC_INTERFACE="eth1"

#Ironic Metal3 setting for IPMI LAN Network
export IRONIC_IPMI_INTERFACE="eth0"
EOF
