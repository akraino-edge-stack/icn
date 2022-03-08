#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/../common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

SITE_REPO=${SITE_REPO:-" https://gerrit.akraino.org/r/icn"}
SITE_BRANCH=${SITE_BRANCH:-"master"}
SITE_PATH=${SITE_PATH:-"deploy/site/vm-mc/deployment"}

function deploy {
    gpg --import ${FLUX_SOPS_PRIVATE_KEY}
    flux_create_site ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH} ${FLUX_SOPS_KEY_NAME}
}

function clean {
    kubectl -n flux-system delete kustomization $(flux_site_kustomization_name ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH})
}

function is_cluster_ready {
    for yaml in ${SCRIPTDIR}/deployment/cluster-*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	if [[ $(kubectl -n ${SITE_NAMESPACE} get cluster ${name} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; then
	    return 1
	fi
    done
}

function is_control_plane_ready {
    # Checking the Cluster resource status is not sufficient, it
    # reports the control plane as ready before the nodes forming the
    # control plane are ready
    for yaml in ${SCRIPTDIR}/deployment/cluster-*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	local replicas=$(kubectl -n ${SITE_NAMESPACE} get kubeadmcontrolplane ${name} -o jsonpath='{.spec.replicas}')
	if [[ $(kubectl --kubeconfig=${BUILDDIR}/${name}-admin.conf get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c True) != ${replicas} ]]; then
	    return 1
	fi
    done
}

function insert_control_plane_network_identity_into_ssh_config {
    # This enables logging into the control plane machines from this
    # machine without specifying the identify file on the command line

    if [[ ! $(which ipcalc) ]]; then
        apt-get install -y ipcalc
    fi

    # Create ssh config if it doesn't exist
    mkdir -p ${HOME}/.ssh && chmod 700 ${HOME}/.ssh
    touch ${HOME}/.ssh/config
    chmod 600 ${HOME}/.ssh/config
    # Add the entry for the control plane network, host value in ssh
    # config is a wildcard
    for yaml in ${SCRIPTDIR}/deployment/cluster-*.yaml; do
	name=$(awk '/name:/ {print $2; exit}' ${yaml})
	endpoint=$(helm -n ${SITE_NAMESPACE} get values -a ${name} | awk '/controlPlaneEndpoint:/ {print $2}')
	prefix=$(helm -n ${SITE_NAMESPACE} get values -a ${name} | awk '/controlPlanePrefix:/ {print $2}')
	host=$(ipcalc ${endpoint}/${prefix} | awk '/Network:/ {sub(/\.0.*/,".*"); print $2}')
	if [[ $(grep -c "Host ${host}" ${HOME}/.ssh/config) != 0 ]]; then
	    sed -i -e '/Host '"${host}"'/,+3 d' ${HOME}/.ssh/config
	fi
	cat <<EOF >>${HOME}/.ssh/config
Host ${host}
  IdentityFile ${SCRIPTDIR}/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
    done
    # Add the identity to authorized keys on this host to enable ssh
    # logins via its control plane address
    authorized_key=$(cat ${SCRIPTDIR}/id_rsa.pub)
    sed -i -e '\!'"${authorized_key}"'!d' ${HOME}/.ssh/authorized_keys
    cat ${SCRIPTDIR}/id_rsa.pub >> ~/.ssh/authorized_keys
}

function wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for is_cluster_ready
    for yaml in ${SCRIPTDIR}/deployment/cluster-*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	clusterctl -n ${SITE_NAMESPACE} get kubeconfig ${name} >${BUILDDIR}/${name}-admin.conf
	chmod 600 ${BUILDDIR}/${name}-admin.conf
    done
    wait_for is_control_plane_ready
    insert_control_plane_network_identity_into_ssh_config
}

function is_cluster_deleted {
    for yaml in ${SCRIPTDIR}/deployment/cluster-*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	! kubectl -n ${SITE_NAMESPACE} get cluster ${name}
    done
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
