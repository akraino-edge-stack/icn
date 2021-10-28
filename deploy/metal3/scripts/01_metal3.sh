#!/usr/bin/env bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

eval "$(go env)"

source $LIBDIR/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root"
    exit 1
fi

function deprovision_compute_node {
    name="$1"
    if kubectl get baremetalhost $name -n metal3 &>/dev/null; then
        kubectl patch baremetalhost $name -n metal3 --type merge \
        -p '{"spec":{"image":{"url":"","checksum":""}}}'
    fi
}

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

    printf "    userData:\n" >>${SCRIPTDIR}/machines-values.yaml
    if [ -n "$username" ]; then
	printf "      name: ${username}\n" >>${SCRIPTDIR}/machines-values.yaml
    fi
    if [ -n "$password" ]; then
        passwd=$(mkpasswd --method=SHA-512 --rounds 4096 "$password")
        printf "      hashedPassword: ${passwd}\n" >>${SCRIPTDIR}/machines-values.yaml
    fi

    if [ -n "$COMPUTE_NODE_FQDN" ]; then
        printf "      fqdn: ${COMPUTE_NODE_FQDN}\n" >>${SCRIPTDIR}/machines-values.yaml
    fi

    if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
        yes y | ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
    fi

    printf "      sshAuthorizedKey: $(cat $HOME/.ssh/id_rsa.pub)\n" >>${SCRIPTDIR}/machines-values.yaml
}

create_networkdata() {
    name="$1"
    node_networkdata $name >>${SCRIPTDIR}/machines-values.yaml
}

function make_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
        printf "  ${name}:\n" >>${SCRIPTDIR}/machines-values.yaml
        printf "    bmcUsername: ${ipmi_username}\n" >>${SCRIPTDIR}/machines-values.yaml
        printf "    bmcPassword: ${ipmi_password}\n" >>${SCRIPTDIR}/machines-values.yaml
        printf "    bmcAddress: ipmi://${ipmi_address}\n" >>${SCRIPTDIR}/machines-values.yaml
	if [[ ! -z ${boot_mac} ]]; then
            printf "    bootMACAddress: ${boot_mac}\n" >>${SCRIPTDIR}/machines-values.yaml
	fi
        printf "    imageName: ${BM_IMAGE}\n" >>${SCRIPTDIR}/machines-values.yaml
        create_userdata $name $os_username $os_password
        create_networkdata $name
    done
}

function configure_nodes {
    if [ ! -d $IRONIC_DATA_DIR ]; then
        mkdir -p $IRONIC_DATA_DIR
    fi

    #make sure nodes.json file in /opt/ironic/ are configured
    if [ ! -f $IRONIC_DATA_DIR/nodes.json ]; then
        cp ${SCRIPTDIR}/nodes.json.sample $IRONIC_DATA_DIR/nodes.json
    fi
}

function deprovision_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
        deprovision_compute_node $name
    done
}

function clean_all {
    helm -n metal3 uninstall machines
    rm -f ${SCRIPTDIR}/machines-values.yaml
    if [ -f $IRONIC_DATA_DIR/nodes.json ]; then
        rm -rf $IRONIC_DATA_DIR/nodes.json
    fi
}

function apply_bm_hosts {
    printf "machines:\n" >${SCRIPTDIR}/machines-values.yaml
    list_nodes | make_bm_hosts
    helm -n metal3 install machines ${SCRIPTDIR}/../../machines --create-namespace -f ${SCRIPTDIR}/machines-values.yaml
}

function deprovision_all_hosts {
    list_nodes | deprovision_bm_hosts
}

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

echo "Usage: metal3.sh"
echo "provision   - provision baremetal node as specified in common.sh"
echo "deprovision - deprovision baremetal node as specified in common.sh"
echo "clean       - clean all the bmh resources"
exit 1
