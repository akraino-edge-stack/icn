#!/usr/bin/env bash
set -eu -o pipefail

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

#KuD repository URL
KUDREPO="${KUDREPO:-https://github.com/onap/multicloud-k8s.git}"
#Path to clone the KuD repo
KUDPATH="/opt/src/github.com/onap/multicloud-k8s"
#KuD version to use
KUD_VERSION="ed96bca7fe415f1636d82c26af15d7474bdfe876"

#EMCO repository URL
EMCOREPO="${EMCOREPO:-https://github.com/open-ness/EMCO.git}"
#Path to clone the EMCO repo
EMCOPATH="/opt/src/github.com/open-ness/EMCO"
#EMCO version to use
EMCO_VERSION="openness-21.03.06"

#Discard existing repo directory
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-true}"

# The kustomize version to use
KUSTOMIZE_VERSION="v4.3.0"

#Cluster API version to use
CAPI_VERSION="v0.4.3"

#The flux version to use
FLUX_VERSION="0.20.0"

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

# Returns "null" when the field is not present
function networkdata_networks_field {
    name=$1
    network=$2
    field=$3
    NODES_FILE="${IRONIC_DATA_DIR}/nodes.json"
    cat $NODES_FILE | jq -c -r --arg name "$name" --arg network "$network" --arg field "$field" '.nodes[] | select(.name==$name) | .net.networks[] | select(.id==$network).'${field}
}

# Returns "null" when the field is not present
function networkdata_links_field {
    name=$1
    link=$2
    field=$3
    NODES_FILE="${IRONIC_DATA_DIR}/nodes.json"
    cat $NODES_FILE | jq -c -r --arg name "$name" --arg link "$link" --arg field "$field" '.nodes[] | select(.name==$name) | .net.links[] | select(.id==$link).'${field}
}

function node_networkdata {
    name=$1

    NODES_FILE="${IRONIC_DATA_DIR}/nodes.json"

    if [ ! -f "$NODES_FILE" ]; then
        exit 1
    fi

    printf "    networks:\n"
    for network in $(cat $NODES_FILE | jq -r --arg name "$name" '.nodes[] | select(.name==$name) | .net.networks[].id'); do
	link=$(networkdata_networks_field $name $network "link")
	type=$(networkdata_networks_field $name $network "type")
	mac=$(networkdata_links_field $name $link "ethernet_mac_address")

	# Optional values
	ip_address=$(networkdata_networks_field $name $network "ip_address")
	gateway=$(networkdata_networks_field $name $network "gateway")
	dns_nameservers=$(networkdata_networks_field $name $network "dns_nameservers")

	printf "      ${network}:\n"
	printf "        macAddress: ${mac}\n"
	printf "        type: ${type}\n"
	if [[ $ip_address != "null" ]]; then
	    printf "        ipAddress: ${ip_address}\n"
	fi
	if [[ $gateway != "null" ]]; then
	    printf "        gateway: ${gateway}\n"
	fi
	if [[ $dns_nameservers != "null" ]]; then
	    printf "        nameservers: ${dns_nameservers}\n"
	fi
    done
}

function wait_for {
    local -r interval=${WAIT_FOR_INTERVAL:-30s}
    local -r max_tries=${WAIT_FOR_TRIES:-20}
    local try=0
    until "$@"; do
        echo "[${try}/${max_tries}] - Waiting ${interval} for $*"
        sleep ${interval}
        try=$((try+1))
        if [[ ${try} -ge ${max_tries} ]]; then
            return 1
        fi
    done
}

function clone_repository {
    local -r path=$1
    local -r repo=$2
    local -r version=$3
    mkdir -p $(dirname ${path})
    if [[ -d ${path} && "${FORCE_REPO_UPDATE}" == "true" ]]; then
       rm -rf "${path}"
    fi
    if [ ! -d "${path}" ] ; then
        pushd $(dirname ${path})
        git clone "${repo}"
        popd
    else
       pushd "${path}"
       git fetch
       popd
    fi
    pushd "${path}"
    git reset --hard "${version}"
    popd
}

function clone_baremetal_operator_repository {
    clone_repository ${BMOPATH} ${BMOREPO} ${BMO_VERSION}
}

function clone_kud_repository {
    clone_repository ${KUDPATH} ${KUDREPO} ${KUD_VERSION}
}

function clone_emco_repository {
    clone_repository ${EMCOPATH} ${EMCOREPO} ${EMCO_VERSION}
}

function install_kustomize {
    curl -sL "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2F${KUSTOMIZE_VERSION}/kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" -o kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz
    tar xzf kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz --no-same-owner
    sudo install -o root -g root -m 0755 kustomize /usr/local/bin/kustomize
    rm kustomize_${KUSTOMIZE_VERSION}_linux_amd64.tar.gz kustomize
    kustomize version
}

function install_clusterctl {
    curl -L https://github.com/kubernetes-sigs/cluster-api/releases/download/${CAPI_VERSION}/clusterctl-linux-amd64 -o clusterctl
    sudo install -o root -g root -m 0755 clusterctl /usr/local/bin/clusterctl
    rm clusterctl
    clusterctl version
}

function install_flux_cli {
    export FLUX_VERSION
    curl -s https://fluxcd.io/install.sh | sudo -E bash
    flux --version
}

function install_emcoctl {
    clone_emco_repository
    make -C ${EMCOPATH}/src/tools/emcoctl
    sudo install -o root -g root -m 0755 ${EMCOPATH}/bin/emcoctl/emcoctl /usr/local/bin/emcoctl
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
