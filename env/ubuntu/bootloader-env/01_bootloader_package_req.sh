#!/usr/bin/env bash
set -ex
shopt -s extglob

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

function download_essential_packages {
    apt-get update
    for package in crudini curl dnsmasq figlet golang nmap patch psmisc \
        python-pip python-requests python-setuptools vim wget; do
        apt-get -d install $package -y
    done
}

function build_baremetal_operator_images {
    if [ ! -d "$BUILD_DIR/baremetal-operator"]; then
    return
    fi

    pushd $BUILD_DIR/baremetal-operator
    docker build -t $IRONIC_BAREMETAL_IMAGE . -f build/Dockerfile
    docker save --output \
    $CONTAINER_IMAGES_DIR/baremetal-operator.tar $IRONIC_BAREMETAL_IMAGE
    popd

    docker pull $IRONIC_BAREMETAL_SOCAT_IMAGE
    docker save --output $CONTAINER_IMAGES_DIR/socat.tar $IRONIC_BAREMETAL_SOCAT_IMAGE
}

function build_ironic_images {
    for images in ironic-image ironic-inspector-image; do
    if [ -d "$BUILD_DIR/$images" ]; then
        pushd $BUILD_DIR/$images
        podman build -t $images .
        popd
    fi
    done

    if podman images -q localhost/ironic-inspector-image ; then
    podman tag localhost/ironic-inspector-image $IRONIC_INSPECTOR_IMAGE
    podman save --output \
        $CONTAINER_IMAGES_DIR/ironic-inspector-image.tar \
        $IRONIC_INSPECTOR_IMAGE
    fi

    if podman images -q localhost/ironic-image ; then
        podman tag localhost/ironic-inspector-image $IRONIC_IMAGE
    podman save --output $CONTAINER_IMAGES_DIR/ironic-image.tar \
        $IRONIC_IMAGE
    fi

    podman pull k8s.gcr.io/pause:3.1
    podman save --output $CONTAINER_IMAGES_DIR/podman-pause.tar \
    k8s.gcr.io/pause:3.1

    #build_baremetal_operator_images
}


function download_container_images {
    check_docker
    pushd $CONTAINER_IMAGES_DIR
    #docker images for Kubernetes
    for images in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
    docker pull k8s.gcr.io/$images:v1.15.0;
    docker save --output $images.tar k8s.gcr.io/$images;
    done

    docker pull k8s.gcr.io/pause:3.1
    docker save --output pause.tar k8s.gcr.io/pause

    docker pull k8s.gcr.io/etcd:3.3.10
    docker save --output etcd.tar k8s.gcr.io/etcd

    docker pull k8s.gcr.io/coredns:1.3.1
    docker save --output coredns.tar k8s.gcr.io/coredns

    #podman images for Ironic
    check_podman
    build_ironic_images
    #podman pull $IRONIC_IMAGE
    #podman save --output ironic.tar $IRONIC_IMAGE
    #podman pull $IRONIC_INSPECTOR_IMAGE
    #podman save --output ironic-inspector.tar $IRONIC_INSPECTOR_IMAGE
    popd
}

function download_build_packages {
    check_curl
    pushd $BUILD_DIR
    if [ ! -f ironic-python-agent.initramfs ]; then
    curl --insecure --compressed \
        -L https://images.rdoproject.org/master/rdo_trunk/current-tripleo-rdo/ironic-python-agent.tar | tar -xf -
    fi

    if [[ "$BM_IMAGE_URL" && "$BM_IMAGE" ]]; then
    curl -o ${BM_IMAGE} --insecure --compressed -O -L ${BM_IMAGE_URL}
    md5sum ${BM_IMAGE} | awk '{print $1}' > ${BM_IMAGE}.md5sum
    fi

    if [ ! -f 87-podman-bridge.conflist ]; then
    curl --insecure --compressed -O -L $PODMAN_CNI_CONFLIST
    fi

    if [ ! -d baremetal-operator ]; then
    git clone https://github.com/metal3-io/baremetal-operator.git
    pushd ./baremetal-operator
    git checkout -b icn_baremetal_operator 11ea02ab5cab8b3ab14972ae7c0e70206bba00b5
    popd
    fi

    if [ ! -d ironic-inspector-image ]; then
    git clone https://github.com/metal3-io/ironic-inspector-image.git
    pushd ./ironic-inspector-image
    git checkout -b icn_ironic_inspector_image 25431bd5b7fc87c6f3cfb8b0431fe66b86bbab0e
    popd
    fi

    if [ ! -d ironic-image ]; then
    git clone https://github.com/metal3-io/ironic-image.git
    pushd ./ironic-image
    git checkout -b icn_ironic_image 329eb4542f0d8d0f0e9cf0d7e550e33b07efe7fb
    popd
    fi
}

function check_pip {
    if ! which pip ; then
    apt-get install python-pip -y
    fi
}

function check_curl {
    if ! which curl ; then
        apt-get install curl -y
    fi
}

function check_apt_tools {
    if ! which add-apt-repository ; then
    apt-get install software-properties-common -y
    fi
}

function download_ironic_packages {
    for package in jq nodejs python-ironicclient \
        python-ironic-inspector-client python-lxml python-netaddr \
        python-openstackclient unzip genisoimage; do
        apt-get -d install $package -y
    done

    check_pip
    pip download lolcat yq -d $PIP_CACHE_DIR
}

function check_docker {
    if which docker ; then
    return
    fi

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
    apt-get install docker-ce=18.06.0~ce~3-0~ubuntu -y
}

function check_podman {
    if which podman; then
    return
    fi

    add-apt-repository -y ppa:projectatomic/ppa
    apt-get update
    apt-get install podman -y
}

function download_docker_packages {
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

function download_podman_packages {
    apt-get update
    add-apt-repository -y ppa:projectatomic/ppa
    apt-get -d install podman -y
}

function download_kubernetes_packages {
    curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
    bash -c 'cat <<EOF >/etc/apt/sources.list.d/kubernetes.list
deb https://apt.kubernetes.io/ kubernetes-xenial main
EOF'
    apt-get update
    apt-get install -d kubelet=1.15.0-00 kubeadm=1.15.0-00 kubectl=1.15.0-00 -y
}

function clean_apt_cache {
    pushd /var/cache/apt/archives

    if [ $(ls -1q . | wc -l ) -ge 3 ]; then
        $(rm !("lock"|"partial"))
    fi
    popd

}

function mv_apt_cache {
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
check_dir $BUILD_DIR
clean_dir $BUILD_DIR
check_dir $CONTAINER_IMAGES_DIR
clean_dir $CONTAINER_IMAGES_DIR
download_essential_packages
download_ironic_packages
download_docker_packages
download_podman_packages
download_kubernetes_packages
download_build_packages
download_container_images
mv_apt_cache
