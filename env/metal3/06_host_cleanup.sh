#!/usr/bin/env bash
set -eux -o pipefail

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/common.sh

# Kill and remove the running ironic containers
for name in ironic ironic-inspector dnsmasq httpd mariadb ipa-downloader; do
    sudo docker ps | grep -w "$name$" && sudo docker kill "$name"
    sudo docker ps --all | grep -w "$name$" && sudo docker rm "$name" -f
done

ip link set provisioning down || true
brctl delbr provisioning || true

ip link set dhcp0 down || true
brctl delbr dhcp0 || true

rm -rf ${IRONIC_DATA_DIR}
