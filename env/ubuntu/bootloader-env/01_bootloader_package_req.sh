#!/usr/bin/env bash
set -ex

source $(dirname $PWD)/../lib/common.sh
source $(dirname $PWD)/../lib/logging.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

if [[ $(lsb_release -d | cut -f2) != $UBUNTU_BIONIC ]]; then
    echo "Currently Ubuntu 18.04.2 LTS is only supported"
    exit 1
fi

function download_essential_packages() {
    apt-get update
	for package in crudini curl dnsmasq figlet golang nmap patch psmisc \
			python-pip python-requests python-setuptools vim wget; do
    	apt-get -d install $package -y
	done
}

function check_pip() {
	if !(which pip); then
		apt-get install python-pip -y
	fi
}

function check_curl() {
	if !(which curl); then
        apt-get install curl -y
    fi
}

function check_apt_tools() {
	if !(which add-apt-repository); then
		apt-get install software-properties-common -y
	fi
}

function download_ironic_packages() {
	for package in jq nodejs python-ironicclient \
			python-ironic-inspector-client python-lxml python-netaddr \
			python-openstackclient unzip genisoimage; do
    	apt-get -d install $package -y
	done
	
	check_pip    
    pip download lolcat yq -d $PIP_CACHE_DIR
}

function download_docker_packages() {
    apt-get remove -y docker \
        docker-engine \
        docker.io \
        containerd \
        runc \
		docker-ce
    apt-get update
	for package in apt-transport-https ca-certificates gnupg-agent \
			software-properties-common; do
    	apt-get -d install $package -y
	done

	check_curl
	check_apt_tools
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    add-apt-repository \
        "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
        $(lsb_release -cs) \
        stable"
    apt-get update
    apt-get -d install docker-ce=18.06.0~ce~3-0~ubuntu -y
}

function download_podman_packages() {
    apt-get update
    add-apt-repository -y ppa:projectatomic/ppa
    apt-get -d install podman -y
}

function download_kubernetes_packages() {
   curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
   bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
   apt-get update
   apt-get install -d kubelet=1.15.0-00 kubeadm=1.15.0-00 kubectl=1.15.0-00 -y
}

function clean_apt_cache() {
	shopt -s extglob
	pushd /var/cache/apt/archives

	if [ $(ls -1q . | wc -l ) -ge 3 ]; then
    	$(rm !("lock"|"partial"))
	fi
	popd
	
}

function mv_apt_cache() {
	shopt -s extglob
    pushd /var/cache/apt/archives

    if [ $(ls -1q . | wc -l ) -gt 2 ]; then
        $(mv !("lock"|"partial") $LOCAL_APT_REPO)
    fi
    popd
}

function check_dir() {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

function clean_dir() {
	shopt -s extglob
    pushd $1

    if [ $(ls -1q . | wc -l ) -ne 0 ]; then
        $(rm -r ./*)
    fi
    popd
}

clean_apt_cache
check_dir $LOCAL_APT_REPO 
clean_dir $LOCAL_APT_REPO 
check_dir $PIP_CACHE_DIR
clean_dir $PIP_CACHE_DIR
download_essential_packages
download_ironic_packages
download_docker_packages
download_podman_packages
download_kubernetes_packages
mv_apt_cache
