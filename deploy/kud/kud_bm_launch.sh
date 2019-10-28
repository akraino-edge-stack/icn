#!/bin/bash
set +x

LIBDIR="$(dirname "$(dirname "$PWD")")"

source $LIBDIR/env/lib/common.sh

function get_kud_repo {
    if [ -d $DOWNLOAD_PATH/multicloud-k8s ]; then
        rm -rf $DOWNLOAD_PATH/multicloud-k8s
    fi

    mkdir -p $DOWNLOAD_PATH
    pushd $DOWNLOAD_PATH
    git clone https://github.com/onap/multicloud-k8s.git
    popd
}

function set_ssh_key {
    if ! [ -f ~/.ssh/id_rsa ]; then
        echo "Generating rsa key for this host"
        ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa <&-
    fi

    if ! grep -qF "$(ssh-keygen -y -f ~/.ssh/id_rsa)" ~/.ssh/authorized_keys; then
        ssh-keygen -y -f ~/.ssh/id_rsa >> ~/.ssh/authorized_keys
    fi

    chmod og-wx ~/.ssh/authorized_keys
}

function set_bm_kud {
    pushd $DOWNLOAD_PATH/multicloud-k8s/kud/hosting_providers/vagrant/inventory
    HOST_IP=${HOST_IP:-$(hostname -I | cut -d ' ' -f 1)}
    if [ "$1" == "virtlet" ] ; then
    cat <<EOL > hosts.ini
[all]
$HOSTNAME ansible_ssh_host=${HOST_IP} ansible_ssh_port=22

[kube-master]
$HOSTNAME

[kube-node]
$HOSTNAME

[etcd]
$HOSTNAME

[virtlet]
$HOSTNAME

[k8s-cluster:children]
kube-node
kube-master
EOL
    else
    cat <<EOL > hosts.ini
[all]
$HOSTNAME ansible_ssh_host=${HOST_IP} ansible_ssh_port=22

[kube-master]
$HOSTNAME

[kube-node]
$HOSTNAME

[etcd]
$HOSTNAME

[k8s-cluster:children]
kube-node
kube-master
EOL
    fi
    popd
}

function kud_install {
    pushd $DOWNLOAD_PATH/multicloud-k8s/kud/hosting_providers/vagrant/
    ./installer.sh | tee kud_minial_deploy.log
    popd
}

function verifier {
    APISERVER=$(kubectl config view --minify -o \
                    jsonpath='{.clusters[0].cluster.server}')
    TOKEN=$(kubectl get secret \
        $(kubectl get serviceaccount default -o \
        jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | \
        base64 --decode )
  call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure
}

get_kud_repo
set_ssh_key
set_bm_kud $1
kud_install
verifier

exit 0
