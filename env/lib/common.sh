#!/usr/bin/env bash
set -eu -o pipefail

IRONIC_DATA_DIR=${IRONIC_DATA_DIR:-"/opt/ironic"}
NODES_FILE=${NODES_FILE:-"${IRONIC_DATA_DIR}/nodes.json"}
#IRONIC_PROVISIONING_INTERFACE is required to be provisioning, don't change it
IRONIC_INTERFACE=${IRONIC_INTERFACE:-}
IRONIC_PROVISIONING_INTERFACE=${IRONIC_PROVISIONING_INTERFACE:-"provisioning"}
IRONIC_PROVISIONING_INTERFACE_IP=${IRONIC_PROVISIONING_INTERFACE_IP:-"172.22.0.1"}
BM_IMAGE_URL=${BM_IMAGE_URL:-"https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"}
BM_IMAGE=${BM_IMAGE:-"focal-server-cloudimg-amd64.img"}

#Baremetal operator repository URL
BMOREPO="${BMOREPO:-https://github.com/metal3-io/baremetal-operator.git}"
#Path to clone the baremetal operator repo
BMOPATH="/opt/src/github.com/metal3-io/baremetal-operator"
#Bare Metal Operator version to use
#  If changing this, the value in deploy/ironic/icn/kustomization.yaml
#  must also be changed
BMO_VERSION="capm3-v0.5.4"

#KuD repository URL
KUDREPO="${KUDREPO:-https://github.com/onap/multicloud-k8s.git}"
#Path to clone the KuD repo
KUDPATH="/opt/src/github.com/onap/multicloud-k8s"
#KuD version to use
KUD_VERSION="8157bf63753839ce4e9006978816fad3f63ca2de"

#EMCO repository URL
EMCOREPO="${EMCOREPO:-https://gitlab.com/project-emco/core/emco-base.git}"
#Path to clone the EMCO repo
EMCOPATH="/opt/src/emco-base"
#EMCO version to use
EMCO_VERSION="v22.03"

#Discard existing repo directory
FORCE_REPO_UPDATE="${FORCE_REPO_UPDATE:-false}"

# The kustomize version to use
KUSTOMIZE_VERSION="v4.5.2"

#Cluster API version to use
CAPI_VERSION="v0.4.7"

#Cluster API version to use
CAPM3_VERSION="v0.5.4"

#The flux version to use
FLUX_VERSION="0.27.0"

#The sops version to use
SOPS_VERSION="v3.7.1"

#Cert-Manager version to use
CERT_MANAGER_VERSION="v1.7.1"

#CNI versions to use in cluster chart
CALICO_VERSION="v3.22.0"
FLANNEL_VERSION="v0.16.3"

#Kata version to use
KATA_VERSION="2.3.2"
KATA_WEBHOOK_VERSION="2.3.2"

#The kubectl version to install when KuD is not used to deploy the
#jump server K8s cluster
KUBECTL_VERSION="v1.20.7"

#The yq version to use
YQ_VERSION="v4.20.1"

#Istio repository URL
ISTIOREPO="${ISTIOREPO:-https://github.com/istio/istio.git}"
#Path to clone the Istio repo
ISTIOPATH="/opt/src/istio"
#Istio version to use
ISTIO_VERSION="1.10.3"

#Addon versions
CDI_VERSION="v1.44.1"
CPU_MANAGER_VERSION="v1.4.1"
KUBEVIRT_VERSION="v0.50.0"
MULTUS_VERSION="v3.8"
NODUS_VERSION="dd9985e5be010b764b324b57c1afe985a59abf68"
QAT_VERSION="v0.23.0"

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

function node_userdata {
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

    printf "userData:\n"
    if [ -n "$username" ]; then
	printf "  name: ${username}\n"
    fi
    if [ -n "$password" ]; then
        passwd=$(mkpasswd --method=SHA-512 --rounds 4096 "$password")
        printf "  hashedPassword: ${passwd}\n"
    fi

    if [ -n "$COMPUTE_NODE_FQDN" ]; then
        printf "  fqdn: ${COMPUTE_NODE_FQDN}\n"
    fi

    if [ ! -f $HOME/.ssh/id_rsa.pub ]; then
        yes y | ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
    fi

    printf "  sshAuthorizedKey: $(cat $HOME/.ssh/id_rsa.pub)\n"
}

# Returns "null" when the field is not present
function networkdata_networks_field {
    name=$1
    network=$2
    field=$3
    cat $NODES_FILE | jq -c -r --arg name "$name" --arg network "$network" --arg field "$field" '.nodes[] | select(.name==$name) | .net.networks[] | select(.id==$network).'${field}
}

# Returns "null" when the field is not present
function networkdata_links_field {
    name=$1
    link=$2
    field=$3
    cat $NODES_FILE | jq -c -r --arg name "$name" --arg link "$link" --arg field "$field" '.nodes[] | select(.name==$name) | .net.links[] | select(.id==$link).'${field}
}

function node_networkdata {
    name=$1

    if [ ! -f "$NODES_FILE" ]; then
        exit 1
    fi

    printf "networks:\n"
    for network in $(cat $NODES_FILE | jq -r --arg name "$name" '.nodes[] | select(.name==$name) | .net.networks[].id'); do
	link=$(networkdata_networks_field $name $network "link")
	type=$(networkdata_networks_field $name $network "type")
	mac=$(networkdata_links_field $name $link "ethernet_mac_address")

	# Optional values
	ip_address=$(networkdata_networks_field $name $network "ip_address")
	gateway=$(networkdata_networks_field $name $network "gateway")
	dns_nameservers=$(networkdata_networks_field $name $network "dns_nameservers")

	printf "  ${network}:\n"
	printf "    macAddress: ${mac}\n"
	printf "    type: ${type}\n"
	if [[ $ip_address != "null" ]]; then
	    printf "    ipAddress: ${ip_address}\n"
	fi
	if [[ $gateway != "null" ]]; then
	    printf "    gateway: ${gateway}\n"
	fi
	if [[ $dns_nameservers != "null" ]]; then
	    printf "    nameservers: ${dns_nameservers}\n"
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

# This is intended to be used together with list_nodes in the
# following way:
#   list_nodes | while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do ...
function node_machine_values {
    printf "machineName: ${name}\n"
    printf "machineLabels:\n"
    printf "  machine: ${name}\n"
    printf "bmcUsername: ${ipmi_username}\n"
    printf "bmcPassword: ${ipmi_password}\n"
    printf "bmcAddress: ipmi://${ipmi_address}\n"
    if [[ ! -z ${boot_mac} ]]; then
        printf "bootMACAddress: ${boot_mac}\n"
    fi
    printf "imageName: ${BM_IMAGE}\n"
    node_userdata ${name} ${os_username} ${os_password}
    node_networkdata ${name}
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

function clone_istio_repository {
    clone_repository ${ISTIOPATH} ${ISTIOREPO} ${ISTIO_VERSION}
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
