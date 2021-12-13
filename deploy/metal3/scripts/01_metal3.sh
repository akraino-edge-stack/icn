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

function make_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
	node_machine_values >${SCRIPTDIR}/${name}-values.yaml
	helm -n metal3 install ${name} ${SCRIPTDIR}/../../machine --create-namespace -f ${SCRIPTDIR}/${name}-values.yaml

    done
}

function configure_nodes {
    if [ ! -d $IRONIC_DATA_DIR ]; then
        mkdir -p $IRONIC_DATA_DIR
    fi

    #make sure nodes.json file in /opt/ironic/ are configured
    if [ ! -f $NODES_FILE ]; then
        cp ${SCRIPTDIR}/nodes.json.sample $NODES_FILE
    fi
}

function deprovision_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
        deprovision_compute_node $name
    done
}

function clean_bm_hosts {
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
	helm -n metal3 uninstall ${name}
	rm -rf ${SCRIPTDIR}/${name}-values.yaml
    done
}

function clean_all {
    list_nodes | clean_bm_hosts
    if [ -f $NODES_FILE ]; then
        rm -rf $NODES_FILE
    fi
}

function apply_bm_hosts {
    list_nodes | make_bm_hosts
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
