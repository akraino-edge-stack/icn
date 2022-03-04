#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

trap err_exit ERR
function err_exit {
    if command -v kubectl; then
	kubectl get all -n baremetal-operator-system
    fi
}

# This may be used to update the in-place Bare Metal Operator YAML
# files from the upstream project
function build_source {
    clone_baremetal_operator_repository
    KUSTOMIZATION_FILES=$(find ${BMOPATH}/config/kustomization.yaml ${BMOPATH}/config/{namespace,default,crd,rbac,manager,webhook,certmanager} -type f)
    for src in ${KUSTOMIZATION_FILES}; do
        dst=${src/${BMOPATH}\/config/${SCRIPTDIR}\/base}
        mkdir -p $(dirname ${dst})
        cp ${src} ${dst}
    done
}

function deploy {
    kustomize build ${SCRIPTDIR}/icn | kubectl apply -f -
    kubectl wait --for=condition=Available --timeout=600s deployment/baremetal-operator-controller-manager -n baremetal-operator-system
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
  build-source  - Rebuild the in-tree Bare Metal Operator YAML files
  clean         - Remove the Bare Metal Operator
  deploy        - Deploy the Bare Metal Operator
EOF
       ;;
esac
