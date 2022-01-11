#!/bin/bash
set -eu -o pipefail

cat <<EOF >user_config.sh
#!/usr/bin/env bash

#Ironic Metal3 settings for provisioning network
export IRONIC_INTERFACE="eth1"
EOF

if [[ ! -z "${DOCKER_REGISTRY_MIRRORS+x}" ]]; then
    cat <<EOF >>user_config.sh

#Use a registry mirror for downloading container images
export DOCKER_REGISTRY_MIRRORS="${DOCKER_REGISTRY_MIRRORS}"
EOF
fi
