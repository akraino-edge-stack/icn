#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function deploy {
    export FLUX_VERSION
    curl -s https://fluxcd.io/install.sh | sudo -E bash
    flux --version
}

case $1 in
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  deploy        - Deploy Flux CLI
EOF
       ;;
esac
