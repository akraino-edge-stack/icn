#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname ${SCRIPTDIR})/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

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

function configure_ironic_interfaces {
    # Add firewall rules to ensure the IPA ramdisk can reach httpd, Ironic and the Inspector API on the host
    if [ "$IRONIC_PROVISIONING_INTERFACE" ]; then
        check_interface_ip $IRONIC_PROVISIONING_INTERFACE $IRONIC_PROVISIONING_INTERFACE_IP
    else
        exit 1
    fi

    for port in 80 5050 6385 ; do
        if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT > /dev/null 2>&1; then
            sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT
        fi
    done

    #Allow access to dhcp and tftp server for pxeboot
    for port in 67 69 ; do
        if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT 2>/dev/null ; then
            sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT
        fi
    done
}

function configure {
    configure_ironic_bridge
    configure_ironic_interfaces
}

configure
