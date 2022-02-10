#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function deploy {
    add-apt-repository -y ppa:longsleep/golang-backports
    apt-get update
    apt-get install golang-go -y
}

case $1 in
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  deploy        - Deploy golang
EOF
       ;;
esac
