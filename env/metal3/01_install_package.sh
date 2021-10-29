#!/usr/bin/env bash
set -eux -o pipefail

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/common.sh
source $LIBDIR/lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function install_essential_packages {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y install \
    ca-certificates \
    crudini \
    curl \
    dnsmasq \
    figlet \
    nmap \
    patch \
    psmisc \
    python3-pip \
    python3-requests \
    python3-setuptools \
    vim \
    wget \
    git \
    software-properties-common

    update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

    add-apt-repository -y ppa:longsleep/golang-backports
    apt-get update
    apt-get install golang-go -y
}

function install_ironic_packages {
    apt-get update
    apt-get -y install \
    jq \
    nodejs \
    python3-ironicclient \
    python3-ironic-inspector-client \
    python3-lxml \
    python3-netaddr \
    python3-openstackclient \
    unzip \
    genisoimage \
    whois

    pip install \
    lolcat \
    yq
}

install() {
    install_essential_packages
    install_ironic_packages
    install_kustomize
    install_clusterctl
    install_flux_cli
}

install
