#!/bin/bash

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

_get_go
_get_pip
_get_ansible
_get_docker
