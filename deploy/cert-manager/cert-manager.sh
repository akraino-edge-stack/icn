#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

# Cert-Manager version to use
CERT_MANAGER_VERSION="v1.5.3"

# This may be used to update the in-place cert-manager YAML
# files from the upstream project
function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml -o ${SCRIPTDIR}/base/cert-manager.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd
}

function deploy {
    kustomize build ${SCRIPTDIR}/icn | kubectl apply -f -
    kubectl -n cert-manager wait --for=condition=Available --timeout=300s deployment --all
}

function clean {
    kustomize build ${SCRIPTDIR}/icn | kubectl delete -f -
}

case $1 in
    "build-source") build_source ;;
    "clean") clean ;;
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree cert-manager YAML files
  clean         - Remove the cert-manager
  deploy        - Deploy the cert-manager
EOF
       ;;
esac
