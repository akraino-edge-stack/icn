#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

NAMEPREFIX="capm3"
ENABLE_DHCP="${IRONIC_ENABLE_DHCP:-yes}"

trap err_exit ERR
function err_exit {
    kubectl get all -n ${NAMEPREFIX}-system
}

function check_interface_ip {
    local -r interface=$1
    local -r ipaddr=$2

    ip addr show dev ${interface}
    if [[ $? -ne 0 ]]; then
        exit 1
    fi

    local -r ipv4address=$(ip addr show dev ${interface} | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    if [[ "$ipv4address" != "$ipaddr" ]]; then
        exit 1
    fi
}

function configure_ironic_bridge {
    if [[ ! $(ip link show dev provisioning) ]]; then
	ip link add dev provisioning type bridge
    fi
    ip link set provisioning up
    ip link set dev ${IRONIC_INTERFACE} master provisioning
    if [[ ! $(ip addr show dev provisioning to 172.22.0.1) ]]; then
	ip addr add dev provisioning 172.22.0.1/24
    fi
}

function configure_ironic_interfaces {
    # Add firewall rules to ensure the IPA ramdisk can reach httpd,
    # Ironic and the Inspector API on the host
    if [ "${IRONIC_PROVISIONING_INTERFACE}" ]; then
        check_interface_ip ${IRONIC_PROVISIONING_INTERFACE} ${IRONIC_PROVISIONING_INTERFACE_IP}
    else
        exit 1
    fi

    for port in 80 5050 6385 ; do
        if ! sudo iptables -C INPUT -i ${IRONIC_PROVISIONING_INTERFACE} -p tcp -m tcp --dport ${port} -j ACCEPT > /dev/null 2>&1; then
            sudo iptables -I INPUT -i ${IRONIC_PROVISIONING_INTERFACE} -p tcp -m tcp --dport ${port} -j ACCEPT
        fi
    done

    # Allow access to dhcp and tftp server for pxeboot
    for port in 67 69 ; do
        if ! sudo iptables -C INPUT -i ${IRONIC_PROVISIONING_INTERFACE} -p udp --dport ${port} -j ACCEPT 2>/dev/null ; then
            sudo iptables -I INPUT -i ${IRONIC_PROVISIONING_INTERFACE} -p udp --dport ${port} -j ACCEPT
        fi
    done
}

function deploy_bridge {
    configure_ironic_bridge
    configure_ironic_interfaces
}

function clean_bridge {
    ip link set provisioning down || true
    ip link del provisioning type bridge || true
}

# This may be used to update the in-place Ironic YAML files from the
# upstream project.  We cannot use the upstream sources directly as
# they require an envsubst step before kustomize build.
function build_source {
    clone_baremetal_operator_repository
    export NAMEPREFIX
    KUSTOMIZATION_FILES=$(find ${BMOPATH}/ironic-deployment/{default,ironic} -type f)
    for src in ${KUSTOMIZATION_FILES}; do
        dst=${src/${BMOPATH}\/ironic-deployment/${SCRIPTDIR}\/base}
        mkdir -p $(dirname ${dst})
        envsubst <${src} >${dst}
    done
    sed -i -e '/name: quay.io\/metal3-io\/ironic/{n;s/newTag:.*/newTag: '"${BMO_VERSION}"'/;}' ${SCRIPTDIR}/icn/kustomization.yaml
}

function deploy {
    fetch_image
    local layer="${SCRIPTDIR}/icn"
    if [[ ${ENABLE_DHCP} != "yes" ]]; then
	layer="${SCRIPTDIR}/icn-no-dhcp"
    fi
    kustomize build ${layer} | kubectl apply -f -
    kubectl wait --for=condition=Available --timeout=600s deployment/${NAMEPREFIX}-ironic -n ${NAMEPREFIX}-system
}

function clean {
    kustomize build ${SCRIPTDIR}/icn | kubectl delete --ignore-not-found=true -f -
    rm -rf ${IRONIC_DATA_DIR}
}

case $1 in
    "build-source") build_source ;;
    "clean") clean ;;
    "clean-bridge") clean_bridge ;;
    "deploy") deploy ;;
    "deploy-bridge") deploy_bridge ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree Ironic YAML files
  clean         - Remove Ironic
  clean-bridge  - Uninstall provisioning network bridge
  deploy        - Deploy Ironic
  deploy-bridge - Install provisioning network bridge
EOF
       ;;
esac
