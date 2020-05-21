#!/bin/bash
set -xe

# shellcheck disable=SC1091
source lib/logging.sh
# shellcheck disable=SC1091
source lib/common.sh

DEPLOYDIR="$(dirname "$PWD")"
BMODIR=$DEPLOYDIR/metal3/scripts/bmo

# Environment variables
COMPUTE_NODE_PASSWORD="${COMPUTE_NODE_PASSWORD:-mypasswd}"
BM_IMAGE=${BM_IMAGE:-"bionic-server-cloudimg-amd64.img"}
IMAGE_URL=http://172.22.0.1/images/${BM_IMAGE}
IMAGE_CHECKSUM=http://172.22.0.1/images/${BM_IMAGE}.md5sum

function launch_baremetal_operator {
    kubectl apply -f $BMODIR/namespace/namespace.yaml
    kubectl apply -f $BMODIR/rbac/service_account.yaml -n metal3
    kubectl apply -f $BMODIR/rbac/role.yaml -n metal3
    kubectl apply -f $BMODIR/rbac/role_binding.yaml
    kubectl apply -f $BMODIR/crds/metal3.io_baremetalhosts_crd.yaml
    kubectl apply -f $BMODIR/operator/no_ironic/operator.yaml -n metal3
}

network_config_files() {
cat << 'EOF'
write_files:
- path: /opt/ironic_net.sh
  owner: root:root
  permissions: '0777'
  content: |
    #!/usr/bin/env bash
    set -xe
    for intf in /sys/class/net/*; do
        sudo ifconfig `basename $intf` up
        sudo dhclient -nw `basename $intf`
    done
runcmd:
 - [ /opt/ironic_net.sh ]
EOF
}

create_userdata() {
    name="$1"
    COMPUTE_NODE_FQDN="$name.akraino.icn.org"
    printf "#cloud-config\n" > $name-userdata.yaml
    if [ -n "$COMPUTE_NODE_PASSWORD" ]; then
        printf "password: ""%s" "$COMPUTE_NODE_PASSWORD" >>  $name-userdata.yaml
        printf "\nchpasswd: {expire: False}\n" >>  $name-userdata.yaml
        printf "ssh_pwauth: True\n" >>  $name-userdata.yaml
    fi

    if [ -n "$COMPUTE_NODE_FQDN" ]; then
        printf "fqdn: ""%s" "$COMPUTE_NODE_FQDN" >>  $name-userdata.yaml
        printf "\n" >>  $name-userdata.yaml
    fi
    printf "disable_root: false\n" >> $name-userdata.yaml
    printf "ssh_authorized_keys:\n  - " >> $name-userdata.yaml

    if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
        yes y | ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
    fi

    cat $HOME/.ssh/id_rsa.pub >> $name-userdata.yaml
    network_config_files >> $name-userdata.yaml
    printf "\n" >> $name-userdata.yaml
}

apply_userdata_credential() {
    name="$1"
    cat <<EOF > ./$name-user-data-credential.yaml
apiVersion: v1
data:
  userData: $(base64 -w 0 $name-userdata.yaml)
kind: Secret
metadata:
  name: $name-user-data
  namespace: metal3
type: Opaque
EOF
    kubectl apply -n metal3 -f $name-user-data-credential.yaml
}

function make_bm_hosts {
    while read -r name address user password mac; do
        create_userdata $name
        apply_userdata_credential $name
        go run "${BMOPATH}"/cmd/make-bm-worker/main.go \
           -address "$address" \
           -password "$password" \
           -user "$user" \
           -boot-mac "$mac" \
           "$name" > $name-bm-node.yaml
        printf "  image:" >> $name-bm-node.yaml
        printf "\n    url: ""%s" "${IMAGE_URL}" >> $name-bm-node.yaml
        printf "\n    checksum: ""%s" "${IMAGE_CHECKSUM}" >> $name-bm-node.yaml
        printf "\n  userData:" >> $name-bm-node.yaml
        printf "\n    name: ""%s" "$name""-user-data" >> $name-bm-node.yaml
        printf "\n    namespace: metal3\n" >> $name-bm-node.yaml
        kubectl apply -f $name-bm-node.yaml -n metal3
    done
}

function apply_bm_hosts {
    list_nodes | make_bm_hosts
}

launch_baremetal_operator
apply_bm_hosts
