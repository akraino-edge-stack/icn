#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

# Upstream QAT plugin includes a kustomization already, but it
# references the intel-qat-plugin.yaml instead of the
# intel-qat-kernel-plugin.yaml, so recreate a kustomization in-tree.
function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL https://raw.githubusercontent.com/intel/intel-device-plugins-for-kubernetes/${QAT_VERSION}/deployments/qat_plugin/base/intel-qat-kernel-plugin.yaml -o ${SCRIPTDIR}/base/instal-qat-kernel-plugin.yaml
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
