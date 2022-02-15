#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function deploy {
    curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" -o kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    tar xzf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz --no-same-owner
    sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz kustomize
    kustomize version
}

case $1 in
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  deploy        - Deploy kustomize
EOF
       ;;
esac
