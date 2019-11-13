#!/bin/bash

#supported OS version
UBUNTU_BIONIC=${UBUNTU_BIONIC:-Ubuntu 18.04.2 LTS}

#offline mode variable
DOWNLOAD_PATH=${DOWNLOAD_PATH:-/opt/icn}
LOCAL_APT_REPO=${LOCAL_APT_REPO:-$DOWNLOAD_PATH/apt}
PIP_CACHE_DIR=${PIP_CACHE_DIR:-$DOWNLOAD_PATH/pip-cache-dir}
BUILD_DIR=${BUILD_DIR:-$DOWNLOAD_PATH/build-dir}
CONTAINER_IMAGES_DIR=${CONTAINER_IMAGES_DIR:-$OFFLINE_DOWNLOAD_PATH/docker-dir}

#set variables
#Todo include over all variables here
KUBE_VERSION=${KUBE_VERSION:-"v1.15.0"}
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"10.244.0.0/16"}
PODMAN_CNI_CONFLIST=${PODMAN_CNI_CONFLIST:-"https://raw.githubusercontent.com/containers/libpod/v1.4.4/cni/87-podman-bridge.conflist"}

#Bootstrap K8s cluster
BS_DHCP_INTERFACE=${BS_DHCP_INTERFACE:-}
BS_DHCP_INTERFACE_IP=${BS_DHCP_INTERFACE_IP:-}
BS_DHCP_DIR=${BS_DHCP_DIR:-$DOWNLOAD_PATH/dhcp}

#User Provider Network configuration
PROVIDER_NETWORK_GATEWAY=${PROVIDER_NETWORK_GATEWAY:-}
PROVIDER_NETWORK_DNS=${PROVIDER_NETWORK_DNS:-}

#Ironic variables
IRONIC_IMAGE=${IRONIC_IMAGE:-"quay.io/metal3-io/ironic:master"}
IRONIC_INSPECTOR_IMAGE=${IRONIC_INSPECTOR_IMAGE:-"quay.io/metal3-io/ironic-inspector"}
IRONIC_BAREMETAL_IMAGE=${IRONIC_BAREMETAL_IMAGE:-"quay.io/metal3-io/baremetal-operator:master"}
IRONIC_BAREMETAL_SOCAT_IMAGE=${IRONIC_BAREMETAL_SOCAT_IMAGE:-"alpine/socat:latest"}

IRONIC_DATA_DIR=${IRONIC_DATA_DIR:-"/opt/ironic"}
#IRONIC_PROVISIONING_INTERFACE is required to be provisioning, don't change it
IRONIC_INTERFACE=${IRONIC_INTERFACE:-}
IRONIC_PROVISIONING_INTERFACE=${IRONIC_PROVISIONING_INTERFACE:-"provisioning"}
IRONIC_IPMI_INTERFACE=${IRONIC_IPMI_INTERFACE:-}
IRONIC_PROVISIONING_INTERFACE_IP=${IRONIC_PROVISIONING_INTERFACE_IP:-"172.22.0.1"}
IRONIC_IPMI_INTERFACE_IP=${IRONIC_IPMI_INTERFACE_IP:-}
BM_IMAGE_URL=${BM_IMAGE_URL:-"https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"}
BM_IMAGE=${BM_IMAGE:-"bionic-server-cloudimg-amd64.img"}

#Todo change into nodes list in json pattern
COMPUTE_NODE_FQDN=${COMPUTE_NODE_FQDN:-".akraino.org"}
COMPUTE_NODE_PASSWORD=${COMPUTE_NODE_PASSWORD:-"mypasswd"}

#refered from onap
function call_api {
    #Runs curl with passed flags and provides
    #additional error handling and debug information

    #Function outputs server response body
    #and performs validation of http_code

    local status
    local curl_response_file="$(mktemp -p /tmp)"
    local curl_common_flags=(-s -w "%{http_code}" -o "${curl_response_file}")
    local command=(curl "${curl_common_flags[@]}" "$@")

    echo "[INFO] Running '${command[@]}'" >&2
    if ! status="$("${command[@]}")"; then
        echo "[ERROR] Internal curl error! '$status'" >&2
        cat "${curl_response_file}"
        rm "${curl_response_file}"
        return 2
    else
        echo "[INFO] Server replied with status: ${status}" >&2
        cat "${curl_response_file}"
        rm "${curl_response_file}"
        if [[ "${status:0:1}" =~ [45] ]]; then
            return 1
        else
            return 0
        fi
    fi
}

function list_nodes {
    NODES_FILE="${IRONIC_DATA_DIR}/nodes.json"

    if [ ! -f $IRONIC_DATA_DIR/nodes.json ]; then
        exit 1
    fi

    cat "$NODES_FILE" | \
        jq '.nodes[] | {
           name,
           username:.ipmi_driver_info.username,
           password:.ipmi_driver_info.password,
           address:.ipmi_driver_info.address
           } |
           .name + " " +
           .username + " " +
           .password + " " +
           .address' \
       | sed 's/"//g'
}

