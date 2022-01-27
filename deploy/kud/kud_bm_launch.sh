#!/usr/bin/env bash
set -eu -o pipefail

LIBDIR="$(dirname "$(dirname "$PWD")")"

source $LIBDIR/env/lib/common.sh

export KUBESPRAY_VERSION=2.16.0

function get_kud_repo {
    clone_kud_repository
    export KUD_ADDONS=multus
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
    DOCKER_OPTIONS=""
    if [[ ! -z "${DOCKER_REGISTRY_MIRRORS+x}" ]]; then
	OPTIONS=""
	for mirror in ${DOCKER_REGISTRY_MIRRORS}; do
	    OPTIONS="${OPTIONS} --registry-mirror=${mirror}"
	done
	DOCKER_OPTIONS="docker_options=\"${OPTIONS# }\""
    fi
    cat <<EOL > hosts.ini
[all]
$HOSTNAME ansible_ssh_host=${HOST_IP} ansible_ssh_port=22 ${DOCKER_OPTIONS}

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
    popd
}

function kud_install {
    pushd ${KUDPATH}/kud/hosting_providers/vagrant/
    ./installer.sh | tee kud_deploy.log
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

get_kud_repo
set_ssh_key
set_bm_kud
kud_install
verifier

exit 0
