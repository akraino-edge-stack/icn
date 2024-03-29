#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

trap err_exit ERR
function err_exit {
    if command -v kubectl; then
	kubectl get all -n cert-manager
    fi
}

# This may be used to update the in-place cert-manager YAML
# files from the upstream project
function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml -o ${SCRIPTDIR}/base/cert-manager.yaml
    rm -f ${SCRIPTDIR}/base/kustomization.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd
}

function deploy {
    kustomize build ${SCRIPTDIR}/icn | kubectl apply -f -
    kubectl -n cert-manager wait --for=condition=Available --timeout=300s deployment --all
}

function clean {
    kustomize build ${SCRIPTDIR}/icn | kubectl delete --ignore-not-found=true -f -
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
