#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

NAMEPREFIX="capm3"

trap err_exit ERR
function err_exit {
    kubectl get all -n ${NAMEPREFIX}-system
}

# This may be used to update the in-place Ironic YAML files from the
# upstream project.  We cannot use the upstream sources directly as
# they require an envsubst step before kustomize build.
function build_source {
    clone_baremetal_operator_repository
    export NAMEPREFIX
    KUSTOMIZATION_FILES=$(find ${BMOPATH}/ironic-deployment/{default,ironic} -type f)
    for src in ${KUSTOMIZATION_FILES}; do
        dst=${src/${BMOPATH}\/ironic-deployment/${SCRIPTDIR}\/base}
        mkdir -p $(dirname ${dst})
        envsubst <${src} >${dst}
    done
    sed -i -e '/name: quay.io\/metal3-io\/ironic/{n;s/newTag:.*/newTag: '"${BMO_VERSION}"'FOOBAR/;}' ${SCRIPTDIR}/icn/kustomization.yaml
}

function deploy {
    fetch_image
    kustomize build ${SCRIPTDIR}/icn | kubectl apply -f -
    kubectl wait --for=condition=Available --timeout=600s deployment/${NAMEPREFIX}-ironic -n ${NAMEPREFIX}-system
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
  build-source  - Rebuild the in-tree Ironic YAML files
  clean         - Remove Ironic
  deploy        - Deploy Ironic
EOF
       ;;
esac
