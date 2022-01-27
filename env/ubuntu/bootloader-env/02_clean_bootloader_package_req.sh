#!/usr/bin/env bash
set -eux -o pipefail

source $(dirname $PWD)/../lib/common.sh
source $(dirname $PWD)/../lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function autoremove {
    rm -rf /etc/apt/sources.list.d/*
}

function clean_essential_packages {
    apt-get update
    for package in crudini curl dnsmasq figlet golang nmap patch psmisc \
        python3-pip python3-requests python3-setuptools vim wget; do
        apt-get remove $package -y
    done
    update-alternatives --remove python /usr/bin/python3
    update-alternatives --remove pip /usr/bin/pip3

    autoremove
}

function check_prerequisite {
    if !(which pip); then
        apt-get install python3-pip -y
    fi
    update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    update-alternatives --install /usr/bin/pip pip /usr/bin/pip3 1

    if !(which curl); then
        apt-get install curl -y
    fi

    if !(which add-apt-repository); then
        apt-get install software-properties-common -y
    fi
}

function clean_ironic_packages {
    for package in python3-ironicclient \
        python3-ironic-inspector-client \
        python3-openstackclient genisoimage; do
        apt-get remove $package -y
    done
}

function clean_docker_packages {
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    apt-get update
    docker rmi -f $(docker image ls -a -q)
    apt-get remove docker-ce -y
    apt-get remove -y docker \
        docker-engine \
        docker.io \
        containerd \
        runc \
        docker-ce
    apt-get purge docker-* -y --allow-change-held-packages
    apt-get update
}

function clean_kubernetes_packages {
    #Just to make sure kubernetes packages are removed during the download
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
    apt-get update
    apt-get remove kubelet kubeadm kubectl -y
}

function clean_apt_cache {
    shopt -s extglob
    pushd /var/cache/apt/archives

    if [ $(ls -1q . | wc -l ) -ge 3 ]; then
        $(rm !("lock"|"partial"))
    fi
    popd

}

if [ "$1" == "--only-packages" ]; then
    check_prerequisite
    clean_docker_packages || true
    autoremove
    exit 0
fi

check_prerequisite
clean_apt_cache
clean_kubernetes_packages
clean_docker_packages
clean_ironic_packages
clean_essential_packages
