#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

echo "Binary Package manager script running..."

if [ -d "~/icn/env/bpa" ]
then
    echo "Dir exits"
else
    mkdir -p ~/icn/env/bpa
    echo "Folder created making the installcscript run"
fi

dest_dir=~/icn/env/bpa
function _get_go {
    version=1.12.4
    local tarball=go$version.linux-amd64.tar.gz
    echo "getting go .."
    wget -N -P $dest_dir https://dl.google.com/go/$tarball
}

function _get_pip {
 echo "python deps..."
 wget -N -P $dest_dir http://mirrors.kernel.org/ubuntu/pool/main/p/python-defaults/python_2.7.15~rc1-1_amd64.deb
 wget -N -P $dest_dir https://packages.ubuntu.com/bionic/build-essential
 wget -N -P $dest_dir http://mirrors.kernel.org/ubuntu/pool/universe/w/wheel/python-wheel_0.30.0-0.2_all.deb
 wget -N -P $dest_dir https://packages.ubuntu.com/bionic/amd64/python-dev/download
 wget -N -P $dest_dir http://archive.ubuntu.com/ubuntu/pool/main/p/python-setuptools/python-setuptools_39.0.1.orig.tar.xz
 wget -N -P $dest_dir http://archive.ubuntu.com/ubuntu/pool/universe/p/python-pip/python-pip_9.0.1.orig.tar.gz
 echo "Get pip"
 #curl -sL https://bootstrap.pypa.io/get-pip.py | sudo python
}

function _get_ansible {
    echo "Get Ansible"
    #_install_pip
    echo "Fetching  deps software properties, pythong software properties"
    wget -N -P $dest_dir http://ftp.us.debian.org/debian/pool/main/s/software-properties/software-properties-common_0.96.20.2-2_all.deb
    wget -N -P $dest_dir http://mirrors.kernel.org/ubuntu/pool/main/s/software-properties/python3-software-properties_0.96.24.32.1_all.deb
    #install ansible using pip.
    echo "fetching ansible.. "
    wget -N -P $dest_dir https://releases.ansible.com/ansible/ansible-2.7.10.tar.gz
}

function _get_docker {
    echo " Fetching deps for docker: apt-https-transport, ca-certs, curl"
    wget -N -P $dest_dir http://launchpadlibrarian.net/338548407/apt-transport-https_1.5_amd64.deb
    wget -N -P $dest_dir  http://launchpadlibrarian.net/364556507/ca-certificates_20180409_all.deb
    #docker 18.06 already pulled onto bootstrap machine
}

function _get_kubespray {
    echo " Fetching Kubespray..."
    wget -nc -P $dest_dir https://github.com/kubernetes-incubator/kubespray/archive/v2.8.2.tar.gz
    echo "Requirements for Kubespray..."
    wget -nc -P $dest_dir https://github.com/drkjam/netaddr/archive/netaddr-0.7.19.tar.gz
    wget -nc -P $dest_dir https://github.com/pallets/jinja/archive/2.9.6.tar.gz
    wget -nc -P $dest_dir http://archive.ubuntu.com/ubuntu/pool/main/p/python-pbr/python-pbr_3.1.1.orig.tar.xz
    #WIP hvac

}

function _get_k8s_components {
    echo "Fetching k8s components..."
    if [ -d "$dest_dir/k8s_components" ]
    then
        echo "Kubespray dir exits"
    else
        mkdir -p $dest_dir/k8s_components
    fi
    k8s_dir=~/icn/env/bpa/k8s_components
    wget -nc -P $k8s_dir https://storage.googleapis.com/kubernetes-release/release/v1.12.7/bin/linux/amd64/kubeadm
    wget -nc -P $k8s_dir https://storage.googleapis.com/kubernetes-release/release/v1.12.7/bin/linux/amd64/hyperkube
    wget -nc -P $k8s_dir https://github.com/coreos/etcd/releases/download/v3.2.24/etcd-v3.2.24-linux-amd64.tar.gz
    wget -nc -P $k8s_dir https://github.com/containernetworking/plugins/releases/download/v0.6.0/cni-plugins-amd64-v0.6.0.tgz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/python-httplib2/0.9.2+dfsg-1/python-httplib2_0.9.2+dfsg.orig.tar.gz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/curl/7.17.1-1ubuntu2/curl_7.17.1.orig.tar.gz
    wget -nc -P $k8s_dir http://mirrors.kernel.org/ubuntu/pool/main/r/rsync/rsync_3.1.2-2.1ubuntu1_amd64.deb
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/bash-completion/1:2.8-1ubuntu1/bash-completion_2.8.orig.tar.gz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/socat/1.7.3.2-2ubuntu2/socat_1.7.3.2.orig.tar.bz2
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/unzip/6.0-21ubuntu1/unzip_6.0.orig.tar.gz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/python-apt/1.6.0/python-apt_1.6.0.tar.xz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/aufs-tools/1:4.9+20170918-1ubuntu1/aufs-tools_4.9+20170918.orig.tar.gz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/software-properties/0.96.24.32.1/software-properties_0.96.24.32.1.tar.xz
    wget -nc -P $k8s_dir https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/ebtables/2.0.10.4-3.5ubuntu2.18.04.3/ebtables_2.0.10.4.orig.tar.gz

}

function _get_kud_role_deps {
    if [ -d "$dest_dir/kud_roles" ]
    then
        echo "Dir exits"
    else
        echo "Kud_roles does not exist"
        mkdir -p $dest_dir/kud_roles
    fi
    kud_dir=$dest_dir/kud_roles

   wget -nc -P $kud_dir https://github.com/andrewrothstein/ansible-go/archive/v2.1.10.tar.gz
   wget -nc -P $kud_dir https://github.com/andrewrothstein/ansible-kubernetes-helm/archive/v1.2.9.tar.gz
   wget -nc -P $kud_dir https://github.com/geerlingguy/ansible-role-docker/archive/2.5.2.tar.gz
}

function _get_addons {
    if [ -d "$dest_dir/addons/" ]
    then
        echo "addons exists.. ok"
    else
        mkdir -p ~$dest_dir/addons
    fi
}
addon_dir=$dest_dir/addons

function _get_addons_multus {
    if [ -d "$addon_dir/multus" ]
    then
        echo "Multus dir exists..."
    else
        mkdir -p $addon_dir/multus
    fi
    wget -nc -P $addon_dir/multus https://github.com/intel/multus-cni/releases/download/v3.3-tp/multus-cni_3.3-tp_linux_amd64.tar.gz

}

function _get_addons_ovn_kubernetes {
    if [ -d "$addon_dir/ovn_kubernetes" ]
    then
        echo "OVN kubernetes dir exists..."
    else
        mkdir -p $addon_dir/ovn_kubernetes
    fi
    echo "Fetching prerequisites for ovn"

    wget -nc -P $addon_dir/ovn_kubernetes http://launchpadlibrarian.net/341403267/openvswitch-common_2.8.0-0ubuntu2_amd64.deb
    wget -nc -P $addon_dir/ovn_kubernetes https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/openvswitch/2.8.0-0ubuntu2/openvswitch_2.8.0.orig.tar.gz
    wget -nc -P $addon_dir/ovn_kubernetes https://github.com/openvswitch/ovn-kubernetes/archive/v0.3.0.tar.gz
    #ASK about ovn4nfv-k8s-plugin
}

function _get_addons_virtlet {
    if [ -d "$addon_dir/virtlet" ]
    then
        echo " Virtlet dir exists..."
    else
        mkdir -p $addon_dir/virtlet
    fi
    wget -nc -P $addon_dir/virtlet https://github.com/Mirantis/criproxy/releases/download/v0.14.0/criproxy
    wget -nc -P $addon_dir/virtlet https://github.com/Mirantis/virtlet/releases/download/v1.4.4/virtletctl
}

function _get_addons_nfd {
    if [ -d "$addon_dir/nfd" ]
    then
        echo "NFD dir exists..."
    else
        mkdir -p $addon_dir/nfd
    fi
    wget -nc -P $addon_dir/nfd https://github.com/kubernetes-incubator/node-feature-discovery
}

function _get_addons_istio {
    if [ -d "$addon_dir/istio" ]
    then
        echo "ISTIO dir exists..."
    else
        mkdir -p $addon_dir/istio
    fi
    wget -nc -P $addon_dir/istio https://github.com/istio/istio/releases/download/1.0.3/istio-1.0.3-linux.tar.gz
}

_get_go
_get_pip
_get_ansible
_get_docker
_get_kubespray
_get_k8s_components
_get_kud_role_deps 
_get_addons
_get_addons_multus
_get_addons_ovn_kubernetes
_get_addons_virtlet
_get_addons_nfd
_get_addons_istio

