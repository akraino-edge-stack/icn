#!/usr/bin/env bash
set -ex

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function install_essential_packages {
    export DEBIAN_FRONTEND=noninteractive
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
    software-properties-common

    add-apt-repository -y ppa:longsleep/golang-backports
    apt-get update
    apt-get install -y golang-go
}

install_essential_packages
