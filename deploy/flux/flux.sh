#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

function deploy {
    flux install
}

function clean {
    flux uninstall
}

case $1 in
    "clean") clean ;;
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  clean         - Uninstall Flux
  deploy        - Install Flux
EOF
       ;;
esac
