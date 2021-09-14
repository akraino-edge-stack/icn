#!/usr/bin/env bash
set -eux -o pipefail

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/logging.sh
source $LIBDIR/lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "confgiure script must be run as root"
    exit 1
fi

function check_interface_ip {
    local interface=$1
    local ipaddr=$2

    ip addr show dev $interface
    if [ $? -ne 0 ]; then
        exit 1
    fi

    local ipv4address=$(ip addr show dev $interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    if [ "$ipv4address" != "$ipaddr" ]; then
        exit 1
    fi
}

function configure_ironic_bridge {
    ip link add dev provisioning type bridge
    ip link set provisioning up
    ip link set dev $IRONIC_INTERFACE master provisioning
    ip addr add dev provisioning 172.22.0.1/24
}

function configure_kubelet {
    swapoff -a
    #Todo addition kubelet configuration
}

function configure_kubeadm {
    #Todo error handing
    if [ "$1" == "offline" ]; then
        for images in kube-apiserver kube-controller-manager kube-scheduler kube-proxy; do
            docker load --input $CONTAINER_IMAGES_DIR/$images.tar;
	done

	docker load --input $CONTAINER_IMAGES_DIR/pause.tar
	docker load --input $CONTAINER_IMAGES_DIR/etcd.tar
	docker load --input $CONTAINER_IMAGES_DIR/coredns.tar
        return
    fi
    kubeadm config images pull --kubernetes-version=$KUBE_VERSION
}

function configure_ironic_interfaces {
    #Todo later to change the CNI networking for podman networking
    # Add firewall rules to ensure the IPA ramdisk can reach httpd, Ironic and the Inspector API on the host
    if [ "$IRONIC_PROVISIONING_INTERFACE" ]; then
        check_interface_ip $IRONIC_PROVISIONING_INTERFACE $IRONIC_PROVISIONING_INTERFACE_IP
    else
        exit 1
    fi

    if [ "$IRONIC_IPMI_INTERFACE" ]; then
        check_interface_ip $IRONIC_IPMI_INTERFACE $IRONIC_IPMI_INTERFACE_IP
    else
        exit 1
    fi

    for port in 80 5050 6385 ; do
        if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT > /dev/null 2>&1; then
            sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT
        fi
    done

    # Allow ipmi to the bmc processes
    if ! sudo iptables -C INPUT -i $IRONIC_IPMI_INTERFACE -p udp -m udp --dport 6230:6235 -j ACCEPT 2>/dev/null ; then
        sudo iptables -I INPUT -i $IRONIC_IPMI_INTERFACE -p udp -m udp --dport 6230:6235 -j ACCEPT
    fi

    #Allow access to dhcp and tftp server for pxeboot
    for port in 67 69 ; do
        if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT 2>/dev/null ; then
            sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT
        fi
    done
}

function configure_ironic_offline {
    if [ ! -d $CONTAINER_IMAGES_DIR ] && [ ! -d $BUILD_DIR ]; then
        exit 1
    fi

    for image in ironic-inspector-image ironic-image podman-pause \
	baremetal-operator socat; do
	if [ ! -f "$CONTAINER_IMAGES_DIR/$image" ]; then
	    exit 1
	fi
    done

    if [ ! -f "$BUILD_DIR/ironic-python-agent.initramfs"] && [ ! -f \
	"$BUILD_DIR/ironic-python-agent.kernel" ] && [ ! -f
	"$BUILD_DIR/$BM_IMAGE" ]; then
        exit 1
    fi

    podman load --input $CONTAINER_IMAGES_DIR/ironic-inspector-image.tar
    podman load --input $CONTAINER_IMAGES_DIR/ironic-image.tar
    podman load --input $CONTAINER_IMAGES_DIR/podman-pause.tar

    docker load --input $CONTAINER_IMAGES_DIR/baremetal-operator.tar
    docker load --input $CONTAINER_IMAGES_DIR/socat.tar

    mkdir -p "$IRONIC_DATA_DIR/html/images"

    cp $BUILD_DIR/ironic-python-agent.initramfs $IRONIC_DATA_DIR/html/images/
    cp $BUILD_DIR/ironic-python-agent.kernel $IRONIC_DATA_DIR/html/images/
    cp $BUILD_DIR/$BM_IMAGE $IRONIC_DATA_DIR/html/images/
    md5sum $BUILD_DIR/$BM_IMAGE | awk '{print $1}' > $BUILD_DIR/${BM_IMAGE}.md5sum
}

function configure_ironic {
    if [ "$1" == "offline" ]; then
        configure_ironic_offline
	return
    fi

    for name in ironic ironic-inspector dnsmasq httpd mariadb ipa-downloader; do
        sudo docker ps | \
            grep -w "$name$" && sudo docker kill "$name"
        sudo docker ps --all | \
            grep -w "$name$" && sudo docker rm "$name" -f
    done
    rm -rf "$IRONIC_DATA_DIR"

    docker pull $IRONIC_IMAGE
    docker pull $IRONIC_INSPECTOR_IMAGE
    docker pull $IPA_DOWNLOADER_IMAGE

    mkdir -p "$IRONIC_DATA_DIR/html/images"
    pushd $IRONIC_DATA_DIR/html/images

    if [[ "$BM_IMAGE_URL" && "$BM_IMAGE" ]]; then
    	curl -o ${BM_IMAGE} --insecure --compressed -O -L ${BM_IMAGE_URL}
    	md5sum ${BM_IMAGE} | awk '{print $1}' > ${BM_IMAGE}.md5sum
    fi
    popd
}

function configure {
    #Kubeadm usage deprecated for v1.0.0 release
    #configure_kubeadm $1
    #configure_kubelet
    configure_ironic $1
    configure_ironic_bridge
    configure_ironic_interfaces
}

if [ "$#" -eq 0 ]; then
    configure online
elif [ "$1" == "-o" ]; then
    configure offline
else
    exit 1
fi
