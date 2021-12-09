#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/../common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

FLUX_SOPS_KEY_NAME=${FLUX_SOPS_KEY_NAME:-"icn-site-vm"} # TODO Replace ICN test key with real key

function build_source {
    sops_encrypt_site ${SCRIPTDIR}/site.yaml ${FLUX_SOPS_KEY_NAME}
}

function deploy {
    flux_create_site https://gerrit.akraino.org/r/icn master deploy/site/pod11 ${FLUX_SOPS_KEY_NAME}
}

function clean {
    kubectl -n flux-system delete kustomization icn-master-site-pod11
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

function insert_control_plane_network_identity_into_ssh_config {
    # This enables logging into the control plane machines from this
    # machine without specifying the identify file on the command line

    # Create ssh config if it doesn't exist
    mkdir -p ${HOME}/.ssh && chmod 700 ${HOME}/.ssh
    touch ${HOME}/.ssh/config
    chmod 600 ${HOME}/.ssh/config
    # Add the entry for the control plane network, host value in ssh
    # config is a wildcard
    endpoint=$(helm -n metal3 get values -a cluster-e2etest | awk '/controlPlaneEndpoint:/ {print $2}')
    prefix=$(helm -n metal3 get values -a cluster-e2etest | awk '/controlPlanePrefix:/ {print $2}')
    host=$(ipcalc ${endpoint}/${prefix} | awk '/Network:/ {sub(/\.0.*/,".*"); print $2}')
    if [[ $(grep -c "Host ${host}" ${HOME}/.ssh/config) != 0 ]]; then
	sed -i -e '/Host '"${host}"'/,+1 d' ${HOME}/.ssh/config
    fi
    cat <<EOF >>${HOME}/.ssh/config
Host ${host}
  IdentityFile ${SCRIPTDIR}/id_rsa
EOF
}

function wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for is_cluster_ready
    clusterctl -n metal3 get kubeconfig e2etest >${BUILDDIR}/e2etest-admin.conf
    chmod 600 ${BUILDDIR}/e2etest-admin.conf
    wait_for is_control_plane_ready
    insert_control_plane_network_identity_into_ssh_config
}

case $1 in
    "build-source") build_source ;;
    "clean") clean ;;
    "deploy") deploy ;;
    "wait") wait_for_all_ready ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree site files
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
