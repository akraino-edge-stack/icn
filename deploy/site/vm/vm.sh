#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

# !!!NOTE!!! THE KEYS USED BELOW ARE FOR TEST PURPOSES ONLY.  DO NOT
# USE THESE OUTSIDE OF THIS ICN VIRTUAL TEST ENVIRONMENT.
function build_source {
    # First decrypt the existing site YAML, otherwise we'll be
    # attempting to encrypt it twice below
    if [[ -f ${SCRIPTDIR}/sops.asc ]]; then
	gpg --import ${SCRIPTDIR}/sops.asc
	sops --decrypt --in-place --config=${SCRIPTDIR}/.sops.yaml ${SCRIPTDIR}/site.yaml || true
    fi

    # To login to guest, ssh -i ${SCRIPTDIR/id_rsa
    ssh-keygen -t rsa -N "" -f ${SCRIPTDIR}/id_rsa <<<y
    SSH_AUTHORIZED_KEY=$(cat ${SCRIPTDIR}/id_rsa.pub)
    # Use ! instead of usual / to avoid escaping / in
    # SSH_AUTHORIZED_KEY
    sed -i -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${SCRIPTDIR}/site.yaml

    # The SOPS portions below are based on the guide located at
    # https://fluxcd.io/docs/guides/mozilla-sops/
    local -r key_name="icn-site-vm"
    # Create an rsa4096 key that does not expire
    gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Real: ${key_name}
EOF
    # Export the public and private keypair from the local GPG keyring
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    gpg --export-secret-keys --armor "${key_fp}" >${SCRIPTDIR}/sops.asc
    gpg --export --armor "${key_fp}" >${SCRIPTDIR}/sops.pub.asc
    # Add .sops.yaml so users won't have to worry about specifying the
    # proper key for the target cluster or namespace
    cat <<EOF > ${SCRIPTDIR}/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(bmcPassword|hashedPassword)$
    pgp: ${key_fp}
EOF

    # SOPS is used to protect the bmcPassword of the machine values
    # and hashedPassword of the cluster values
    HASHED_PASSWORD=$(mkpasswd --method=SHA-512 --rounds 10000 "mypasswd")
    sed -i -e 's!hashedPassword: .*!hashedPassword: '"${HASHED_PASSWORD}"'!' ${SCRIPTDIR}/site.yaml

    sops --encrypt --in-place --config=${SCRIPTDIR}/.sops.yaml ${SCRIPTDIR}/site.yaml
}

function deploy {
    flux create source git icn --url=https://gerrit.akraino.org/r/icn --branch=master

    gpg --import ${SCRIPTDIR}/sops.asc
    local -r key_name="icn-site-vm"
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    local -r secret_name="icn-site-vm-sops-gpg"
    kubectl -n flux-system delete secret ${secret_name} || true
    gpg --export-secret-keys --armor "${key_fp}" |
	kubectl -n flux-system create secret generic ${secret_name} --from-file=sops.asc=/dev/stdin

    flux create kustomization site-vm --path=./deploy/site/vm --source=GitRepository/icn --prune=true \
	 --decryption-provider=sops --decryption-secret=${secret_name}
}

function clean {
    kubectl -n flux-system delete kustomization site-vm
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
  build         - Build the site deployment values
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
EOF
       ;;
esac
