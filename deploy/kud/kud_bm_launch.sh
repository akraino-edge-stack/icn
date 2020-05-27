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
    if [ "$1" == "v1" ] ; then
        git clone --branch v1.0-icn https://github.com/akraino-icn/multicloud-k8s.git
    else
        #git clone https://github.com/onap/multicloud-k8s.git
        git clone "https://gerrit.onap.org/r/multicloud/k8s"
        cd k8s && git fetch "https://gerrit.onap.org/r/multicloud/k8s" refs/changes/76/107676/31 && git checkout FETCH_HEAD && cd .. && mv k8s multicloud-k8s
    fi
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
    if [ "$1" == "minimal" ] ; then
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

[ovn-central]
$HOSTNAME

[ovn-controller]
$HOSTNAME

[virtlet]
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
    if [ "$1" == "all" -o "$1" == "vm" ]; then
        sed -i -e 's/testing_enabled=${KUD_ENABLE_TESTS:-false}/testing_enabled=${KUD_ENABLE_TESTS:-true}/g' installer.sh
    fi
    if [ "$1" == "vm" ]; then
        sed -i -e 's/^kube_pods_subnet.*/kube_pods_subnet: 172.21.64.0\/18/g' inventory/group_vars/k8s-cluster.yml
    fi
    ./installer.sh | tee kud_deploy.log

    if [ "$1" == "bm" ]; then
        for addon in ${KUD_ADDONS:-optane}; do
            pushd $DOWNLOAD_PATH/multicloud-k8s/kud/tests/
                bash ${addon}.sh
            popd
        done
    fi
    popd
}

function kud_reset {
    pushd $DOWNLOAD_PATH/multicloud-k8s/kud/hosting_providers/vagrant/
    ansible-playbook -i inventory/hosts.ini /opt/kubespray-2.10.4/reset.yml \
        --become --become-user=root -e reset_confirmation=yes
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

if [ "$1" == "reset" ] ; then
    kud_reset
    exit 0
fi

get_kud_repo $2
set_ssh_key
set_bm_kud $1
kud_install $1
verifier

exit 0
