#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/../common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

FLUX_SOPS_KEY_NAME=${FLUX_SOPS_KEY_NAME:-"icn-site-vm"}

# !!!NOTE!!! THE KEYS USED BELOW ARE FOR TEST PURPOSES ONLY.  DO NOT
# USE THESE OUTSIDE OF THIS ICN VIRTUAL TEST ENVIRONMENT.
function build_source {
    # First decrypt the existing site YAML, otherwise we'll be
    # attempting to encrypt it twice below
    if [[ -f ${SCRIPTDIR}/sops.asc ]]; then
	gpg --import ${SCRIPTDIR}/sops.asc
	sops_decrypt_site ${SCRIPTDIR}/site.yaml
    fi

    # Generate user password and authorized key in site YAML
    # To login to guest, ssh -i ${SCRIPTDIR}/id_rsa
    HASHED_PASSWORD=$(mkpasswd --method=SHA-512 --rounds 10000 "mypasswd")
    sed -i -e 's!hashedPassword: .*!hashedPassword: '"${HASHED_PASSWORD}"'!' ${SCRIPTDIR}/site.yaml
    ssh-keygen -t rsa -N "" -f ${SCRIPTDIR}/id_rsa <<<y
    SSH_AUTHORIZED_KEY=$(cat ${SCRIPTDIR}/id_rsa.pub)
    # Use ! instead of usual / to avoid escaping / in
    # SSH_AUTHORIZED_KEY
    sed -i -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${SCRIPTDIR}/site.yaml

    # Encrypt the site YAML
    create_gpg_key ${FLUX_SOPS_KEY_NAME}
    sops_encrypt_site ${SCRIPTDIR}/site.yaml ${FLUX_SOPS_KEY_NAME}

    # ONLY FOR TEST ENVIRONMENT: save the private key used
    export_gpg_private_key ${FLUX_SOPS_KEY_NAME} >${SCRIPTDIR}/sops.asc
}

function deploy {
    gpg --import ${SCRIPTDIR}/sops.asc
    flux_create_site https://gerrit.akraino.org/r/icn master deploy/site/vm ${FLUX_SOPS_KEY_NAME}
}

function clean {
    kubectl -n flux-system delete kustomization icn-master-site-vm
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
    "build-source") build_source ;;
    "clean") clean ;;
    "deploy") deploy ;;
    "wait") wait_for_all_ready ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Build the in-tree site values
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
