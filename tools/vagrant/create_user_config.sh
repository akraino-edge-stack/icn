#!/bin/bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
ICNDIR="$(dirname $(dirname ${SCRIPTDIR}))"

sed -i -e 's/IRONIC_INTERFACE=.*/IRONIC_INTERFACE="eth1"/' ${ICNDIR}/user_config.sh

if [[ ! -z "${DOCKER_REGISTRY_MIRRORS+x}" ]]; then
    sed -i -e 's/DOCKER_REGISTRY_MIRRORS=.*/DOCKER_REGISTRY_MIRRORS="'"${DOCKER_REGISTRY_MIRRORS}"'"/' ${ICNDIR}/user_config.sh
else
    sed -i -e 's/DOCKER_REGISTRY_MIRRORS=.*/DOCKER_REGISTRY_MIRRORS=""/' ${ICNDIR}/user_config.sh
fi
