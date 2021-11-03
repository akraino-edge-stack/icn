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
    sed -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${SCRIPTDIR}/clusters-values.yaml >${BUILDDIR}/clusters-values.yaml
}

function deploy {
    helm -n metal3 install machines ${SCRIPTDIR}/../../machines --create-namespace -f ${BUILDDIR}/machines-values.yaml
    helm -n metal3 install clusters ${SCRIPTDIR}/../../clusters --create-namespace -f ${BUILDDIR}/clusters-values.yaml
}

function clean {
    helm -n metal3 uninstall clusters
    helm -n metal3 uninstall machines
}

function is_cluster_ready {
    [[ $(kubectl -n metal3 get cluster e2etest -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') == "True" ]]
}

function are_kustomizations_ready {
    [[ $(kubectl --kubeconfig=${BUILDDIR}/e2etest-admin.conf get Kustomization -n flux-system -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c -v True) == 0 ]]
}

function are_helmreleases_ready {
    [[ $(kubectl --kubeconfig=${BUILDDIR}/e2etest-admin.conf get HelmRelease -n flux-system -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c -v True) == 0 ]]
}

function wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    wait_for is_cluster_ready
    clusterctl -n metal3 get kubeconfig e2etest >${BUILDDIR}/e2etest-admin.conf
    chmod 600 ${BUILDDIR}/e2etest-admin.conf
    # TODO The following checks are not ideal: resources created by
    # operators aren't detected here, but this is the best that can be
    # currently done
    WAIT_FOR_INTERVAL=30s
    wait_for are_kustomizations_ready
    wait_for are_helmreleases_ready
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
