#!/usr/bin/env bash
set -eu -o pipefail

LIBDIR="$(dirname "$(dirname "$PWD")")"

source $LIBDIR/env/lib/common.sh

export KUBESPRAY_VERSION=2.16.0

function get_kud_repo {
    clone_kud_repository
    if [ "$1" == "v1" ] ; then
        export KUD_ADDONS=multus
    fi
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
    pushd ${KUDPATH}/kud/hosting_providers/vagrant/inventory
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
    pushd ${KUDPATH}/kud/hosting_providers/vagrant/
    if [ "$1" == "all" ]; then
        sed -i -e 's/testing_enabled=${KUD_ENABLE_TESTS:-false}/testing_enabled=${KUD_ENABLE_TESTS:-true}/g' installer.sh
    fi
    ./installer.sh | tee kud_deploy.log

    if [ "$1" == "bm" ]; then
        for addon in ${KUD_ADDONS:-multus ovn4nfv nfd sriov qat cmk optane}; do
            pushd ${KUDPATH}/kud/tests/
                bash ${addon}.sh
            popd
        done
    fi
    popd
}

function kud_reset {
    pushd ${KUDPATH}/kud/hosting_providers/vagrant/
    ansible-playbook -i inventory/hosts.ini /opt/kubespray-${KUBESPRAY_VERSION}/reset.yml \
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
