#!/usr/bin/env bash
set -ex

lib/common.sh
lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function install_essential_packages() {
    apt-get update
    apt-get -y install \
		crudini \
		curl \
		dnsmasq \
		figlet \
		golang \
		nmap \
		patch \
		psmisc \
		python-pip \
		python-requests \
		python-setuptools \
		vim \
		wget
}

function install_ironic_packages() {
    cd
    if [ ! -d tripleo-repos ]; then
      git clone https://git.openstack.org/openstack/tripleo-repos
    fi
    pushd tripleo-repos
    python setup.py install
    popd
    apt-get update
    apt-get -y install \
		ansible \
		dnsutils \
		jq \
		nodejs \
		python-ironicclient \
		python-ironic-inspector-client \
		python-lxml \
		python-netaddr \
		python-openstackclient \
		qemu-kvm \
		unzip \
		genisoimage
    pip install \
		lolcat \
		yq
}

function install_docker_packages() {
    apt-get remove docker \
		docker-engine \
		docker.io \
		containerd \
		runc
    apt-get update
    apt-get -y install \
		apt-transport-https \
		ca-certificates \
		curl \
		gnupg-agent \
		software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository \
		"deb [arch=amd64] https://download.docker.com/linux/ubuntu \
		$(lsb_release -cs) \
		stable"
    apt-get update
    apt-get -y install docker-ce=18.06.0~ce~3-0~ubuntu
}

function install_podman_packages() {
    apt-get update
    apt-get -y  install software-properties-common
    add-apt-repository -y ppa:projectatomic/ppa
    apt-get -y install podman=1.4.3-1~ubuntu18.04~ppa2
}

function install_kubernetes_packages() {
   apt-get update && apt-get install -y apt-transport-https curl
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
   apt-get update
   apt-get install -y kubelet=1.15.0-00 kubeadm=1.15.0-00 kubectl=1.15.0-00
   apt-mark hold kubelet kubeadm kubectl
}
