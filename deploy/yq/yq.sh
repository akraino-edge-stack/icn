#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function deploy {
    curl -LO "https://github.com/mikefarah/yq/releases/download/${YQ_VERSION}/yq_linux_amd64" -o yq
    sudo install -o root -g root -m 0755 yq /usr/local/bin/yq
    rm yq
}

case $1 in
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  deploy        - Deploy yq
EOF
       ;;
esac
