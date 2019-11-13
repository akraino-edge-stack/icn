#!/usr/bin/env bash
set -x
LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/common.sh

# Kill and remove the running ironic containers
for name in ironic ironic-inspector dnsmasq httpd mariadb; do
    sudo docker ps | grep -w "$name$" && sudo docker kill $name
    sudo docker ps --all | grep -w "$name$" && sudo docker rm $name -f
done

ip link set provisioning down
brctl delbr provisioning

ip link set dhcp0 down
brctl delbr dhcp0

rm -rf ${BS_DHCP_DIR}
rm -rf ${IRONIC_DATA_DIR}

#Kubeadm usage is deprecated in v1.0.0
#kubeadm reset -f
#iptables -F && iptables -t nat -F && iptables -t mangle -F && iptables -X
#rm -rf $HOME/.kube/config
#rm -rf /var/lib/etcd
