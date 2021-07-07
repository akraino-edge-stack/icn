#!/usr/bin/env bash
set -eux -o pipefail

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function install_essential_packages {
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get -y install \
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
    apt-get install -y golang-go
}

install_essential_packages
