#!/usr/bin/env bash
set -xe

source lib/logging.sh
source lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "confgiure script must be run as root"
    exit 1
fi

function configure_kubelet() {
	swapoff -a
	#Todo addition kubelet configuration
}

function configure_kubeadm() {
	#Todo error handing
	kubeadm config images pull --kubernetes-version=$KUBE_VERSION
}

function configure_podman() {
	#Todo later to change the CNI networking for podman networking
}
