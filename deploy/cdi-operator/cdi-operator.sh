#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL https://github.com/kubevirt/containerized-data-importer/releases/download/${CDI_VERSION}/cdi-operator.yaml -o ${SCRIPTDIR}/base/cdi-operator.yaml
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
