#!/bin/bash
set -eu -o pipefail

cat <<EOF >user_config.sh
#!/usr/bin/env bash

#Ironic Metal3 settings for provisioning network
export IRONIC_INTERFACE="eth1"
EOF
