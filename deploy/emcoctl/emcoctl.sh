#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function deploy {
    clone_emco_repository
    make -C ${EMCOPATH}/src/tools/emcoctl
    sudo install -o root -g root -m 0755 ${EMCOPATH}/bin/emcoctl/emcoctl /usr/local/bin/emcoctl
}

case $1 in
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  deploy        - Deploy emcoctl
EOF
       ;;
esac
