#!/usr/bin/env bash
set -eu -o pipefail

LIBDIR="$(dirname "$(dirname "$(dirname "$PWD")")")"

eval "$(go env)"

source $LIBDIR/env/lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

IMAGE_URL=http://172.22.0.1/images/${BM_IMAGE}
IMAGE_CHECKSUM=http://172.22.0.1/images/${BM_IMAGE}.md5sum

function get_default_interface_ipaddress {
    local _ip=$1
    local _default_interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
    local _ipv4address=$(ip addr show dev $_default_interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    eval $_ip="'$_ipv4address'"
}

function create_ssh_key {
    #ssh key for compute node to communicate back to bootstrap server
    mkdir -p $BUILD_DIR/ssh_key
    ssh-keygen -C "compute.icn.akraino.lfedge.org" -f $BUILD_DIR/ssh_key/id_rsa
    cat $BUILD_DIR/ssh_key/id_rsa.pub >> $HOME/.ssh/authorized_keys
}

function set_compute_key {
    _SSH_LOCAL_KEY=$(cat $BUILD_DIR/ssh_key/id_rsa)
    cat << EOF
write_files:
- path: /opt/ssh_id_rsa
    owner: root:root
    permissions: '0600'
    content: |
    $_SSH_LOCAL_KEY
EOF
}

function deprovision_compute_node {
    name="$1"
    kubectl patch baremetalhost $name -n metal3 --type merge \
    -p '{"spec":{"image":{"url":"","checksum":""}}}'
}

function set_compute_ssh_config {
    get_default_interface_ipaddress default_addr
    cat << EOF
- path: /root/.ssh/config
    owner: root:root
    permissions: '0600'
    content: |
    Host bootstrapmachine $default_addr
    HostName $default_addr
    IdentityFile /opt/ssh_id_rsa
    User $USER
- path: /etc/apt/sources.list
    owner: root:root
    permissions: '0665'
    content: |
    deb [trusted=yes] ssh://$USER@$default_addr:$LOCAL_APT_REPO ./
EOF
}

# documentation for the values below may be found at
# https://cloudinit.readthedocs.io/en/latest/topics/modules.html
function create_userdata {
    name="$1"
    username="$2"
    password="$3"
    COMPUTE_NODE_FQDN="$name.akraino.icn.org"

    # validate that the user isn't expecting the deprecated
    # COMPUTE_NODE_PASSWORD to be used
    if [ "$password" != "${COMPUTE_NODE_PASSWORD:-$password}" ]; then
        cat <<EOF
COMPUTE_NODE_PASSWORD "$COMPUTE_NODE_PASSWORD" not equal to nodes.json $name password "$password".
Unset COMPUTE_NODE_PASSWORD and retry.
EOF
        exit 1
    fi

    printf "#cloud-config\n" >  $name-userdata.yaml
    if [ -n "$password" ]; then
        if [ -n "$username" ]; then
            passwd=$(mkpasswd --method=SHA-512 --rounds 4096 "$password")
            printf "users:" >>  $name-userdata.yaml
            printf "\n  - name: ""%s" "$username" >>  $name-userdata.yaml
            printf "\n    lock_passwd: False" >>  $name-userdata.yaml # necessary to allow password login
            printf "\n    passwd: ""%s" "$passwd" >>  $name-userdata.yaml
            printf "\n    sudo: \"ALL=(ALL) NOPASSWD:ALL\"" >>  $name-userdata.yaml
        else
            printf "password: ""%s" "$password" >>  $name-userdata.yaml
        fi
        printf "\nchpasswd: {expire: False}\n" >>  $name-userdata.yaml
        printf "ssh_pwauth: True\n" >>  $name-userdata.yaml
    fi

    if [ -n "$COMPUTE_NODE_FQDN" ]; then
        printf "fqdn: ""%s" "$COMPUTE_NODE_FQDN" >>  $name-userdata.yaml
        printf "\n" >>  $name-userdata.yaml
    fi
    printf "disable_root: false\n" >>  $name-userdata.yaml
    printf "ssh_authorized_keys:\n  - " >>  $name-userdata.yaml

    if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
        yes y | ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
    fi

    cat $HOME/.ssh/id_rsa.pub >>  $name-userdata.yaml
    network_config_files >> $name-userdata.yaml
    printf "\n" >>  $name-userdata.yaml
}

function launch_baremetal_operator {
    docker pull $IRONIC_BAREMETAL_IMAGE
    kubectl apply -f bmo/namespace/namespace.yaml
    kubectl apply -f bmo/rbac/service_account.yaml -n metal3
    kubectl apply -f bmo/rbac/role.yaml -n metal3
    kubectl apply -f bmo/rbac/role_binding.yaml
    kubectl apply -f bmo/crds/metal3.io_baremetalhosts_crd.yaml
    kubectl apply -f bmo/operator/no_ironic/operator.yaml -n metal3
}

function remove_baremetal_operator {
    kubectl delete -f bmo/operator/no_ironic/operator.yaml -n metal3
    kubectl delete -f bmo/crds/metal3.io_baremetalhosts_crd.yaml
    kubectl delete -f bmo/rbac/role_binding.yaml
    kubectl delete -f bmo/rbac/role.yaml -n metal3
    kubectl delete -f bmo/rbac/service_account.yaml -n metal3
    kubectl delete -f bmo/namespace/namespace.yaml
}

function network_config_files {
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
EOF
cat << EOF
- path: /opt/user_net.sh
  owner: root:root
  permissions: '0777'
  content: |
    #!/usr/bin/env bash
    set -xe
    route add default gw $PROVIDER_NETWORK_GATEWAY
    sed -i -e 's/^#DNS=.*/DNS=$PROVIDER_NETWORK_DNS/g' /etc/systemd/resolved.conf
    systemctl daemon-reload
    systemctl restart systemd-resolved
runcmd:
 - [ /opt/ironic_net.sh ]
 - [ /opt/user_net.sh ]
EOF
}

function apply_userdata_credential {
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
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address os_username os_password os_image_name; do
        create_userdata $name $os_username $os_password
        apply_userdata_credential $name

        go run $GOPATH/src/github.com/metal3-io/baremetal-operator/cmd/make-bm-worker/main.go \
           -address "ipmi://$ipmi_address" \
           -password "$ipmi_password" \
           -user "$ipmi_username" \
           "$name" > $name-bm-node.yaml

        printf "  image:" >> $name-bm-node.yaml
        printf "\n    url: ""%s" "$IMAGE_URL" >> $name-bm-node.yaml
        printf "\n    checksum: ""%s" "$IMAGE_CHECKSUM" >> $name-bm-node.yaml
        printf "\n  userData:" >> $name-bm-node.yaml
        printf "\n    name: ""%s" "$name""-user-data" >> $name-bm-node.yaml
        printf "\n    namespace: metal3" >> $name-bm-node.yaml
        printf "\n  rootDeviceHints:" >> $name-bm-node.yaml
        printf "\n    minSizeGigabytes: 48\n" >> $name-bm-node.yaml
        kubectl apply -f $name-bm-node.yaml -n metal3
    done
}

function configure_nodes {
    if [ ! -d $IRONIC_DATA_DIR ]; then
        mkdir -p $IRONIC_DATA_DIR
    fi

    #make sure nodes.json file in /opt/ironic/ are configured
    if [ ! -f $IRONIC_DATA_DIR/nodes.json ]; then
        cp $PWD/nodes.json.sample $IRONIC_DATA_DIR/nodes.json
    fi
}

function remove_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address os_username os_password os_image_name; do
        deprovision_compute_node $name
    done
}

function cleanup {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address os_username os_password os_image_name; do
        kubectl delete bmh $name -n metal3
        kubectl delete secrets $name-bmc-secret -n metal3
        kubectl delete secrets $name-user-data -n metal3
        if [ -f $name-bm-node.yaml ]; then
            rm -rf $name-bm-node.yaml
        fi

        if [ -f $name-user-data-credential.yaml ]; then
            rm -rf $name-user-data-credential.yaml
        fi

        if [ -f $name-userdata.yaml ]; then
            rm -rf $name-userdata.yaml
        fi
    done
}

function clean_all {
    list_nodes | cleanup
    if [ -f $IRONIC_DATA_DIR/nodes.json ]; then
        rm -rf $IRONIC_DATA_DIR/nodes.json
    fi
}

function apply_bm_hosts {
    list_nodes | make_bm_hosts
}

function deprovision_all_hosts {
    list_nodes | remove_bm_hosts
}

if [ "$1" == "launch" ]; then
    launch_baremetal_operator
    exit 0
fi

if [ "$1" == "deprovision" ]; then
    configure_nodes
    deprovision_all_hosts
    exit 0
fi

if [ "$1" == "provision" ]; then
    configure_nodes
    apply_bm_hosts
    exit 0
fi

if [ "$1" == "clean" ]; then
    configure_nodes
    clean_all
    exit 0
fi

if [ "$1" == "remove" ]; then
    remove_baremetal_operator
    exit 0
fi

echo "Usage: metal3.sh"
echo "launch      - Launch the metal3 operator"
echo "provision   - provision baremetal node as specified in common.sh"
echo "deprovision - deprovision baremetal node as specified in common.sh"
echo "clean       - clean all the bmh resources"
echo "remove      - remove baremetal operator"
exit 1

#Following code is tested for the offline mode
#Will be intergrated for the offline mode for ICNi v.0.1.0 beta
#create_ssh_key
#create_userdata
#set_compute_key
#set_compute_ssh_config
