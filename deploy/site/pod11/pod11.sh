#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/../common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

SITE_REPO=${SITE_REPO:-"https://gerrit.akraino.org/r/icn"}
SITE_BRANCH=${SITE_BRANCH:-"master"}
SITE_PATH=${SITE_PATH:-"deploy/site/pod11/deployment"}

function deploy {
    # TODO Replace ICN test key with real key
    flux_create_site ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH} ${FLUX_SOPS_KEY_NAME}
}

function clean {
    kubectl -n flux-system delete kustomization $(flux_site_kustomization_name ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH})
}

function is_cluster_ready {
    [[ $(kubectl -n ${SITE_NAMESPACE} get cluster icn -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') == "True" ]]
}

function is_control_plane_ready {
    # Checking the Cluster resource status is not sufficient, it
    # reports the control plane as ready before the nodes forming the
    # control plane are ready
    local -r replicas=$(kubectl -n ${SITE_NAMESPACE} get kubeadmcontrolplane icn -o jsonpath='{.spec.replicas}')
    [[ $(kubectl --kubeconfig=${BUILDDIR}/icn-admin.conf get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c True) == ${replicas} ]]
}

function wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for is_cluster_ready
    clusterctl -n ${SITE_NAMESPACE} get kubeconfig icn >${BUILDDIR}/icn-admin.conf
    chmod 600 ${BUILDDIR}/icn-admin.conf
    wait_for is_control_plane_ready
}

function is_cluster_deleted {
    ! kubectl -n ${SITE_NAMESPACE} get cluster icn
}

function wait_for_all_deleted {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for is_cluster_deleted
}

case $1 in
    "clean") clean ;;
    "deploy") deploy ;;
    "wait") wait_for_all_ready ;;
    "wait-clean") wait_for_all_deleted ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
