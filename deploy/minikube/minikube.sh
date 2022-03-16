#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

CONTAINERD_VERSION="1.4.11-1"
DOCKER_VERSION="5:20.10.10~3-0~ubuntu-focal"
KUBE_VERSION="1.21.6-00"
KUBERNETES_VERSION="v1.21.6"

function deploy_docker {
    mkdir -p /etc/docker
    cat <<EOF | tee /etc/docker/daemon.json
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2"
}
EOF
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
    add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
    apt-get install -y ca-certificates docker-ce=${DOCKER_VERSION} docker-ce-cli=${DOCKER_VERSION} containerd.io=${CONTAINERD_VERSION}
    systemctl enable --now docker
}

function install_kubectl {
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add -
    add-apt-repository "deb https://apt.kubernetes.io/ kubernetes-xenial main"
    apt-get update -y
    apt-get install -y kubectl=${KUBE_VERSION}
}

function deploy {
    deploy_docker

    curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install -o root -g root -m 0755 minikube-linux-amd64 /usr/local/bin/minikube
    sudo apt-get -y install conntrack

    export CHANGE_MINIKUBE_NONE_USER=true
    mkdir "${HOME}/.kube" && chmod 700 "${HOME}/.kube"
    # The none driver turns this host into a k8s cluster
    minikube start --driver=none --kubernetes-version ${KUBERNETES_VERSION}
    # TODO The kubectl throttling warning is tied to permissions on
    # "${HOME}/.kube/cache".  The CHANGE_MINIKUBE_NONE_USER=true
    # appears to be insufficient.  Need to sudo chown -R
    # ${USER}:${USER} ${HOME}/.kube/cache
    sudo chown -R "${USER}:${USER}" "${HOME}/.kube/cache"

    install_kubectl
}

function clean {
    minikube stop
    minikube delete
}

case $1 in
    "clean") clean
    "deploy") deploy ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  clean         - Remove minikube cluster
  deploy        - Deploy minikube cluster
EOF
       ;;
esac
