#!/usr/bin/env bash
set -x
LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/common.sh

# Kill and remove the running ironic containers
for name in ironic ironic-inspector dnsmasq httpd mariadb; do
    sudo podman ps | grep -w "$name$" && sudo podman kill $name
    sudo podman ps --all | grep -w "$name$" && sudo podman rm $name -f
done

# Remove existing pod
if  sudo podman  pod exists ironic-pod ; then
    sudo podman  pod rm ironic-pod -f
fi

ip link set provisioning down
brctl delbr provisioning

ip link set dhcp0 down
brctl delbr dhcp0

rm -rf ${BS_DHCP_DIR}
rm -rf ${IRONIC_DATA_DIR}
