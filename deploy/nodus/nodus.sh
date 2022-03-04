#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL https://raw.githubusercontent.com/akraino-edge-stack/icn-nodus/${NODUS_VERSION}/deploy/ovn-daemonset.yaml -o ${SCRIPTDIR}/base/ovn-daemonset.yaml
    curl -sL https://raw.githubusercontent.com/akraino-edge-stack/icn-nodus/${NODUS_VERSION}/deploy/ovn4nfv-k8s-plugin.yaml -o ${SCRIPTDIR}/base/ovn4nfv-k8s-plugin.yaml
    rm -f ${SCRIPTDIR}/base/kustomization.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd
}

case $1 in
    "build-source") build_source ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree YAML files
EOF
       ;;
esac
