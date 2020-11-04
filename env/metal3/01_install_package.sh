#!/usr/bin/env bash
set -ex

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/common.sh
source $LIBDIR/lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function install_essential_packages {
    apt-get update
    apt-get -y install \
    crudini \
    curl \
    dnsmasq \
    figlet \
    nmap \
    patch \
    psmisc \
    python-pip \
    python-requests \
    python-setuptools \
    vim \
    wget \
    git \
    software-properties-common \
    bridge-utils

    add-apt-repository -y ppa:longsleep/golang-backports
    apt-get update
    apt-get install golang-go -y
}

function install_ironic_packages {
    apt-get update
    apt-get -y install \
    jq \
    nodejs \
    python-ironicclient \
    python-ironic-inspector-client \
    python-lxml \
    python-netaddr \
    python-openstackclient \
    unzip \
    genisoimage \
    whois

    if [ "$1" == "offline" ]; then
    pip install --no-index
        --find-links=file:$PIP_CACHE_DIR locat yq
    return
    fi

    pip install \
    lolcat \
    yq
}

function install_docker_packages {
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
    if [ "$1" != "offline" ]; then
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    apt-get update
    fi
    apt-get -y install docker-ce=18.06.0~ce~3-0~ubuntu
}

function install_podman_packages {
    if [ "$1" != "offline" ]; then
        add-apt-repository -y ppa:projectatomic/ppa
    apt-get update
    fi
    apt-get -y install podman
}

function install_kubernetes_packages {
    if [ "$1" != "offline" ]; then
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
    apt-get update
    fi
    apt-get install -y kubelet=1.15.0-00 kubeadm=1.15.0-00 kubectl=1.15.0-00
    apt-mark hold kubelet kubeadm kubectl
}

install() {
    install_essential_packages
    install_ironic_packages $1

    #install_docker_packages $1
    #install_podman_packages $1
    #install_kubernetes_packages $1
}

if ["$1" == "-o"]; then
    install offline
    exit 0
fi

install
