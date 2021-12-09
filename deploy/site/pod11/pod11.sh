#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

FLUX_SOPS_KEY_NAME=${FLUX_SOPS_KEY_NAME:"icn-site-vm"} # TODO Replace ICN test key with real key

function build_source {
    local -r key_name=${FLUX_SOPS_KEY_NAME}
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    gpg --export --armor "${key_fp}" >${SCRIPTDIR}/sops.pub.asc
    # Add .sops.yaml so users won't have to worry about specifying the
    # proper key for the target cluster or namespace
    cat <<EOF > ${SCRIPTDIR}/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(bmcPassword|hashedPassword)$
    pgp: ${key_fp}
EOF
}

function deploy {
    flux create source git icn --url=https://gerrit.akraino.org/r/icn --branch=master

    local -r key_name=${FLUX_SOPS_KEY_NAME}
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    local -r secret_name="icn-site-pod11-sops-gpg"
    kubectl -n flux-system delete secret ${secret_name} || true
    gpg --export-secret-keys --armor "${key_fp}" |
	kubectl -n flux-system create secret generic ${secret_name} --from-file=sops.asc=/dev/stdin

    flux create kustomization site-pod11 --path=./deploy/site/pod11 --source=GitRepository/icn --prune=true \
	 --decryption-provider=sops --decryption-secret=${secret_name}
}

function clean {
    kubectl -n flux-system delete kustomization site-pod11
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
  build-source  - Rebuild the in-tree site files
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
