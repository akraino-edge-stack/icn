#!/bin/bash
set -xe

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/logging.sh
source $LIBDIR/lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "launch script must be run as root"
    exit 1
fi

function get_default_interface_ipaddress {
    local _ip=$1
    local _default_interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
    local _ipv4address=$(ip addr show dev $_default_interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    eval $_ip="'$_ipv4address'"
}

function check_cni_network {
    #since bootstrap cluster is a single node cluster,
    #podman and bootstap cluster have same network configuration to avoid the cni network conf conflicts
    if [ ! -d "/etc/cni/net.d" ]; then
        mkdir -p "/etc/cni/net.d"
    fi

    if [ -f "/etc/cni/net.d/87-podman-bridge.conflist" ]; then
        rm -rf /etc/cni/net.d/87-podman-bridge.conflist
    fi

    if [ "$1" == "offline" ]; then
        cp $BUILD_DIR/87-podman-bridge.conflist /etc/cni/net.d/
        return
    fi

    if !(wget $PODMAN_CNI_CONFLIST -P /etc/cni/net.d/); then
        exit 1
    fi
}

function create_k8s_regular_user {
    if [ ! -d "$HOME/.kube" ]; then
        mkdir -p $HOME/.kube
    fi

    if [ ! -f /etc/kubernetes/admin.conf]; then
        exit 1
    fi

    cp -rf /etc/kubernetes/admin.conf $HOME/.kube/config
    chown $(id -u):$(id -g) $HOME/.kube/config
}

function check_k8s_node_status {
    echo 'checking bootstrap cluster single node status'
    node_status="False"

    for i in {1..5}; do
        check_node=$(kubectl get node -o \
            jsonpath='{.items[0].status.conditions[?(@.reason == "KubeletReady")].status}')
        if [ $check_node != "" ]; then
            node_status=${check_node}
        fi

        if [ $node_status == "True" ]; then
            break
        fi

        sleep 3
    done

    if [ $node_status != "True" ]; then
        echo "bootstrap cluster single node status is not ready"
        exit 1
    fi
}

function install_ironic_container {
    # set password for mariadb
    mariadb_password=$(echo $(date;hostname)|sha256sum |cut -c-20)

    # Start image downloader container
    docker run -d --net host --privileged --name ipa-downloader \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

    docker wait ipa-downloader

    # Start dnsmasq, http, mariadb, and ironic containers using same image
    # See this file for env vars you can set, like IP, DHCP_RANGE, INTERFACE
    docker run -d --net host --privileged --name dnsmasq \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/rundnsmasq "${IRONIC_IMAGE}"

    # For available env vars, see:
    docker run -d --net host --privileged --name httpd \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/runhttpd "${IRONIC_IMAGE}"

    # https://github.com/metal3-io/ironic/blob/master/runmariadb.sh
    docker run -d --net host --privileged --name mariadb \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/runmariadb \
        --env "MARIADB_PASSWORD=$mariadb_password" "${IRONIC_IMAGE}"

    # See this file for additional env vars you may want to pass, like IP and INTERFACE
    docker run -d --net host --privileged --name ironic \
        --env-file "${PWD}/ironic.env" \
        --env "MARIADB_PASSWORD=$mariadb_password" \
        -v "$IRONIC_DATA_DIR:/shared" "${IRONIC_IMAGE}"

    # Start Ironic Inspector
    docker run -d --net host --privileged --name ironic-inspector \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" "${IRONIC_INSPECTOR_IMAGE}"
}

function remove_k8s_noschedule_taint {
    #Bootstrap cluster is a single node
    nodename=$(kubectl get node -o jsonpath='{.items[0].metadata.name}')
    if !(kubectl taint node $nodename node-role.kubernetes.io/master:NoSchedule-); then
        exit 1
    fi
}

function install_k8s_single_node {
    get_default_interface_ipaddress apiserver_advertise_addr
    kubeadm_init="kubeadm init --kubernetes-version=$KUBE_VERSION \
        --pod-network-cidr=$POD_NETWORK_CIDR \
        --apiserver-advertise-address=$apiserver_advertise_addr"
    if !(${kubeadm_init}); then
        exit 1
    fi
}

function install_dhcp {
    if [ ! -d $BS_DHCP_DIR ]; then
        mkdir -p $BS_DHCP_DIR
    fi

    #make sure the dhcp conf sample are configured
    if [ ! -f $BS_DHCP_DIR/dhcpd.conf ]; then
        cp $PWD/05_dhcp.conf.sample $BS_DHCP_DIR/dhcpd.conf
    fi

    kubectl create -f $PWD/04_dhcp.yaml
}

function reset_dhcp {
    kubectl delete -f $PWD/04_dhcp.yaml
    if [ -d $BS_DHCP_DIR ]; then
        rm -rf $BS_DHCP_DIR
    fi
}

function create_ironic_env {
    cat <<EOF > ${PWD}/ironic.env
PROVISIONING_INTERFACE=provisioning
DHCP_RANGE=172.22.0.10,172.22.0.100
DEPLOY_KERNEL_URL=http://172.22.0.1/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://172.22.0.1/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=http://172.22.0.1:6385/v1/
IRONIC_INSPECTOR_ENDPOINT=http://172.22.0.1:5050/v1/
CACHEURL=http://172.22.0.1/images
IRONIC_FAST_TRACK=false
EOF
}

function install {
    #Kubeadm usage is deprecated in v1,0,0 version
    #install_kubernetes
    #install_k8s_single_node
    #check_cni_network $1
    #create_k8s_regular_user
    #check_k8s_node_status
    #remove_k8s_noschedule_taint

    #install_podman
    #Todo - error handling mechanism
    create_ironic_env
    install_ironic_container
}

if [ "$1" == "-o" ]; then
    install offline
    exit 0
fi

if [ "$1" == "--dhcp-start" ]; then
    install_dhcp
    echo "wait for 320s for nodes to be assigned"
    sleep 6m
    exit 0
fi

if [ "$1" == "--dhcp-reset" ]; then
    reset_dhcp
    echo "wait for 320s for nodes to be re-assigned"
    sleep 6m
    exit 0
fi

install
