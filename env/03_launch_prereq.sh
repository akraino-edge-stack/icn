#!/bin/bash
set -xe

source lib/logging.sh
source lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "confgiure script must be run as root"
    exit 1
fi

get_default_inteface_ipaddress() {
	local _ip=$1
	local _default_interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
	local _ipv4address=$(ip addr show dev $_default_interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
	eval $_ip="'$_ipv4address'"
}

check_cni_network() {
	#since bootstrap cluster is a single node cluster,
	#podman and bootstap cluster have same network configuration to avoid the cni network conf conflicts
	if [ ! -d "/etc/cni/net.d" ]; then
		mkdir -p "/etc/cni/net.d"
	fi

	if [ ! -f "/etc/cni/net.d/87-podman-bridge.conflist" ]; then
		if !(wget $PODMAN_CNI_CONFLIST -P /etc/cni/net.d/); then
			exit 1
		fi
	fi
}

create_k8s_regular_user() {
	if [ ! -d "$HOME/.kube" ]; then
		mkdir -p $HOME/.kube
	fi

	if [ ! -f /etc/kubernetes/admin.conf]; then
		exit 1
	fi

	cp -rf /etc/kubernetes/admin.conf $HOME/.kube/config
	chown $(id -u):$(id -g) $HOME/.kube/config
}

check_k8s_node_status(){
	echo 'checking bootstrap cluster single node status'
	node_status="False"

	for i in {1..5}
		do
			check_node=$(kubectl get node -o \
						jsonpath='{.items[0].status.conditions[?(@.reason == "KubeletReady")].status}')
			if [ $check_node != "" ]; then
				node_status=${check_node}
			fi

			if [ $node_status == "True" ]; then
				break
			fi

			sleep 3
		done

	if [ $node_status != "True" ]; then
		echo "bootstrap cluster single node status is not ready"
		exit 1
	fi
}

remove_k8s_noschedule_taint() {
	#Bootstrap cluster is a single node
	nodename=$(kubectl get node -o jsonpath='{.items[0].metadata.name}')
	if !(kubectl taint node $nodename node-role.kubernetes.io/master:NoSchedule-); then
		exit 1
	fi
}

install_k8s_single_node() {
	get_default_inteface_ipaddress apiserver_advertise_addr
	kubeadm_init="kubeadm init --kubernetes-version=$KUBE_VERSION \
					--pod-network-cidr=$POD_NETWORK_CIDR \
					--apiserver-advertise-address=$apiserver_advertise_addr"
	if !(${kubeadm_init}); then
		exit 1
	fi
}


install_k8s_single_node
check_cni_network
create_k8s_regular_user
check_k8s_node_status
remove_k8s_noschedule_taint
