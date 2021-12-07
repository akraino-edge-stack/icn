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
    sed -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${SCRIPTDIR}/cluster-e2etest-values.yaml >${BUILDDIR}/cluster-e2etest-values.yaml
}

function release_name {
    local -r values_path=$1
    name=$(basename ${values_path})
    echo ${name%-values.yaml}
}

function deploy {
    for values in ${BUILDDIR}/machine-*-values.yaml; do
	helm -n metal3 install $(release_name ${values}) ${SCRIPTDIR}/../../machine --create-namespace -f ${values}
    done
    helm -n metal3 install cluster-e2etest ${SCRIPTDIR}/../../cluster --create-namespace -f ${BUILDDIR}/cluster-e2etest-values.yaml
}

function clean {
    helm -n metal3 uninstall cluster-e2etest
    for values in ${BUILDDIR}/machine-*-values.yaml; do
	helm -n metal3 uninstall $(release_name ${values})
    done
}

function is_cluster_ready {
    [[ $(kubectl -n metal3 get cluster e2etest -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') == "True" ]]
}

function is_control_plane_ready {
    # Checking the Cluster resource status is not sufficient, it
    # reports the control plane as ready before the nodes forming the
    # control plane are ready
    local -r replicas=$(kubectl -n metal3 get kubeadmcontrolplane e2etest -o jsonpath='{.spec.replicas}')
    [[ $(kubectl --kubeconfig=${BUILDDIR}/e2etest-admin.conf get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c True) == ${replicas} ]]
}

function wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for is_cluster_ready
    clusterctl -n metal3 get kubeconfig e2etest >${BUILDDIR}/e2etest-admin.conf
    chmod 600 ${BUILDDIR}/e2etest-admin.conf
    wait_for is_control_plane_ready
}

case $1 in
    "build") build ;;
    "clean") clean ;;
    "deploy") deploy ;;
    "wait") wait_for_all_ready ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build         - Build the site deployment values
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
