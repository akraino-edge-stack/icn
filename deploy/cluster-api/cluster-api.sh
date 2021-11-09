#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

function deploy {
    export EXP_CLUSTER_RESOURCE_SET=true
    clusterctl init --infrastructure=metal3:${CAPM3_VERSION}
}

function clean {
    clusterctl delete --all
}

case $1 in
    "clean") clean ;;
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  clean         - Remove Cluster API
  deploy        - Deploy Cluster API
EOF
       ;;
esac
