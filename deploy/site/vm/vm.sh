#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

function build {
    SSH_AUTHORIZED_KEY=$(cat ${HOME}/.ssh/id_rsa.pub)
    # Use ! instead of usual / to avoid escaping / in
    # SSH_AUTHORIZED_KEY
    sed -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${SCRIPTDIR}/clusters-values.yaml >${BUILDDIR}/clusters-values.yaml
}

function deploy {
    helm -n metal3 install machines ${SCRIPTDIR}/../../machines --create-namespace -f ${BUILDDIR}/machines-values.yaml
    helm -n metal3 install clusters ${SCRIPTDIR}/../../clusters --create-namespace -f ${BUILDDIR}/clusters-values.yaml
}

function clean {
    helm -n metal3 uninstall clusters
    helm -n metal3 uninstall machines
}

case $1 in
    "build") build ;;
    "clean") clean ;;
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build         - Build the site deployment values
  clean         - Remove the site
  deploy        - Deploy the site
EOF
       ;;
esac
