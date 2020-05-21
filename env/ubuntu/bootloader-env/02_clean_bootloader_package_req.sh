#!/usr/bin/env bash
set -ex

source $(dirname $PWD)/../lib/common.sh
source $(dirname $PWD)/../lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function autoremove {
    #apt-get autoremove -y
    rm -rf /etc/apt/sources.list.d/*
}

function clean_essential_packages {
    apt-get update
    for package in crudini curl dnsmasq figlet golang nmap patch psmisc \
        python-pip python-requests python-setuptools vim wget; do
        apt-get remove $package -y
    done

    autoremove
}

function check_prerequisite {
    if !(which pip); then
        apt-get install python-pip -y
    fi

    if !(which curl); then
        apt-get install curl -y
    fi

    if !(which add-apt-repository); then
        apt-get install software-properties-common -y
    fi
}

function clean_ironic_packages {
    for package in python-ironicclient \
        python-ironic-inspector-client \
        python-openstackclient genisoimage; do
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

function clean_podman_packages {
    apt-get update
    add-apt-repository -y ppa:projectatomic/ppa
    apt-get remove podman -y
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

function clean_all {
    apt-get remove -y openvswitch-switch openvswitch-common ovn-central \
        ovn-common ovn-host
    rm -rf /var/run/openvswitch
    rm -rf /var/lib/openvswitch
    rm -rf /var/log/openvswitch
    rm -rf /var/lib/libvirt
    rm -rf /etc/libvirt
    rm -rf /var/lib/virtlet
    rm -rf /var/run/libvirt
    rm -rf virtlet.sock
    rm -rf virtlet-diag.sock
    rm -rf criproxy.sock
    systemctl stop dockershim
    systemctl stop criproxy
    systemctl disable kubelet
    systemctl disable dockershim
    systemctl disable criproxy
    ip link delete virbr0-nic
    ip link delete virbr0
}

function clean_apt_cache {
    shopt -s extglob
    pushd /var/cache/apt/archives

    if [ $(ls -1q . | wc -l ) -ge 3 ]; then
        $(rm !("lock"|"partial"))
    fi
    popd

}

function mv_apt_cache {
    shopt -s extglob
    pushd /var/cache/apt/archives

    if [ $(ls -1q . | wc -l ) -gt 2 ]; then
        $(mv !("lock"|"partial") $LOCAL_APT_REPO)
    fi
    popd
}

function check_dir {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

function clean_dir {
    shopt -s extglob
    pushd $1

    if [ $(ls -1q . | wc -l ) -ne 0 ]; then
        $(rm -r ./*)
    fi
    popd
}

if [ "$1" == "--only-packages" ]; then
    check_prerequisite
    clean_docker_packages || true
    #clean_ironic_packages
    autoremove
    exit 0
fi

if [ "$1" == "--bm-cleanall" ]; then
    clean_all
    autoremove
    exit 0
fi

check_prerequisite
clean_apt_cache
check_dir $LOCAL_APT_REPO
clean_dir $LOCAL_APT_REPO
check_dir $PIP_CACHE_DIR
clean_dir $PIP_CACHE_DIR
check_dir $BUILD_DIR
clean_dir $BUILD_DIR
check_dir $CONTAINER_IMAGES_DIR
clean_dir $CONTAINER_IMAGES_DIR
clean_kubernetes_packages
clean_podman_packages
clean_docker_packages
clean_ironic_packages
clean_essential_packages
rm -rf $LOCAL_APT_REPO
rm -rf $PIP_CACHE_DIR
rm -rf $BUILD_DIR
rm -rf $CONTAINER_IMAGES_DIR
