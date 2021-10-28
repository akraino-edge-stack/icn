#!/usr/bin/env bash
set -eu -o pipefail

DOWNLOAD_PATH=${DOWNLOAD_PATH:-/opt/icn}

IRONIC_DATA_DIR=${IRONIC_DATA_DIR:-"/opt/ironic"}
#IRONIC_PROVISIONING_INTERFACE is required to be provisioning, don't change it
IRONIC_INTERFACE=${IRONIC_INTERFACE:-}
IRONIC_PROVISIONING_INTERFACE=${IRONIC_PROVISIONING_INTERFACE:-"provisioning"}
IRONIC_IPMI_INTERFACE=${IRONIC_IPMI_INTERFACE:-}
IRONIC_PROVISIONING_INTERFACE_IP=${IRONIC_PROVISIONING_INTERFACE_IP:-"172.22.0.1"}
BM_IMAGE_URL=${BM_IMAGE_URL:-"https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"}
BM_IMAGE=${BM_IMAGE:-"bionic-server-cloudimg-amd64.img"}

#Baremetal operator repository URL
BMOREPO="${BMOREPO:-https://github.com/metal3-io/baremetal-operator.git}"
#Path to clone the baremetal operator repo
BMOPATH="/opt/src/github.com/metal3-io/baremetal-operator"
#Bare Metal Operator version to use
BMO_VERSION="capm3-v0.5.1"
#Discard existing baremetal operator repo directory
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

# The kustomize version to use
KUSTOMIZE_VERSION="v4.3.0"

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

    if [ ! -f "$NODES_FILE" ]; then
        exit 1
    fi

    # The boot MAC address must be specified when a port is included
    # in the IPMI driver address (i.e when using the VirtualBMC
    # controller).  Note that the below is a bit of a hack as it only
    # checks the first entry in NODES_FILE for the port.
    if cat "$NODES_FILE" |
            jq -r '.nodes[0].ipmi_driver_info.address' | grep -c ':[0-9]\+$' >/dev/null; then
        BOOT_LINK=$(cat "$NODES_FILE" |
                        jq -r '.nodes[0].net.links | map(.id=="provisioning_nic") | index(true)')
        cat "$NODES_FILE" |
            jq -r --argjson BOOT_LINK $BOOT_LINK '.nodes[] | [
               .name,
               .ipmi_driver_info.username,
               .ipmi_driver_info.password,
               .ipmi_driver_info.address,
               .net.links[$BOOT_LINK].ethernet_mac_address,
               .os.username,
               .os.password,
               .os.image_name
               ] | @csv' |
            sed 's/"//g'
    else
        cat "$NODES_FILE" |
            jq -r '.nodes[] | [
               .name,
               .ipmi_driver_info.username,
               .ipmi_driver_info.password,
               .ipmi_driver_info.address,
               "",
               .os.username,
               .os.password,
               .os.image_name
               ] | @csv' |
            sed 's/"//g'
    fi
}

function node_networkdata {
    name=$1

    NODES_FILE="${IRONIC_DATA_DIR}/nodes.json"

    if [ ! -f "$NODES_FILE" ]; then
        exit 1
    fi

    cat $NODES_FILE  | jq -r --arg name "$name" '.nodes[] | select(.name==$name) | .net'
}

function clone_baremetal_operator_repository {
    mkdir -p $(dirname ${BMOPATH})
    if [[ -d ${BMOPATH} && "${FORCE_REPO_UPDATE}" == "true" ]]; then
       rm -rf "${BMOPATH}"
    fi
    if [ ! -d "${BMOPATH}" ] ; then
        pushd $(dirname ${BMOPATH})
        git clone "${BMOREPO}"
        popd
    else
       pushd "${BMOPATH}"
       git fetch
       popd
    fi
    pushd "${BMOPATH}"
    git reset --hard "${BMO_VERSION}"
    popd
}

function install_kustomize {
    curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" -o kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    tar xzf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz --no-same-owner
    sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz kustomize
    kustomize version
}

function fetch_image {
    if [[ "${BM_IMAGE_URL}" && "${BM_IMAGE}" ]]; then
       mkdir -p "${IRONIC_DATA_DIR}/html/images"
       pushd ${IRONIC_DATA_DIR}/html/images
       local_checksum="0"
       if [[ -f "${BM_IMAGE}" ]]; then
           local_checksum=$(md5sum ${BM_IMAGE} | awk '{print $1}')
       fi
       remote_checksum=$(curl -sL "$(dirname ${BM_IMAGE_URL})/MD5SUMS" | grep ${BM_IMAGE} | awk '{print $1}')
       if [[ ${local_checksum} != ${remote_checksum} ]]; then
            curl -o ${BM_IMAGE} --insecure --compressed -O -L ${BM_IMAGE_URL}
            md5sum ${BM_IMAGE} | awk '{print $1}' > ${BM_IMAGE}.md5sum
       fi
       popd
    fi
}
