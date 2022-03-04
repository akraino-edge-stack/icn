#!/bin/bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname ${SCRIPTDIR})/env/lib"
ICNDIR="$(dirname ${SCRIPTDIR})"

source $LIBDIR/common.sh

function table_header {
    cat <<EOF
|Component|Version|
|---|---|
EOF
}

function jump_server_os {
    case $(awk '/m.vm.box = / {print $3}' ${ICNDIR}/Vagrantfile | tr -d "'") in
	"intergratedcloudnative/ubuntu2004") version="Ubuntu 20.04" ;;
	*) version="UNKNOWN" ;;
    esac
    echo "|OS|${version}|"
}

function kubespray_version {
    awk -F= '/KUBESPRAY_VERSION=/ {print $2}' ${ICNDIR}/deploy/kud/kud_bm_launch.sh
}
 
function jump_server_k8s {
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/kubespray-defaults/defaults/main.yaml | awk '/kube_version:/ {print $2}')
    echo "|K8s|${version} (Kubespray $(kubespray_version))|"
}

function jump_server_cri {
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/container-engine/docker/defaults/main.yml | awk '/docker_version:/ {print $2}' | tr -d "'")
    echo "|Docker|${version} (Kubespray $(kubespray_version))|"
}

function jump_server_cni {
    # kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml:kube_network_plugin: flannel
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/download/defaults/main.yml | awk '/flannel_version:/ {print $2}' | tr -d '"')
    echo "|Flannel|${version} (Kubespray $(kubespray_version))|"
}

function jump_server_addons {
    cat <<EOF
|Ironic|${BMO_VERSION}|
|cert-manager|${CERT_MANAGER_VERSION}|
|Bare Metal Operator|${BMO_VERSION}|
|Cluster API|${CAPI_VERSION}|
|Flux|${FLUX_VERSION}|
EOF
}

function jump_server {
    table_header
    jump_server_os
    jump_server_k8s
    jump_server_cri
    jump_server_cni
    jump_server_addons
}

function compute_cluster_os {
    case $(awk '/imageName:/ {print $2}' ${ICNDIR}/deploy/cluster/values.yaml) in
	"focal-server-cloudimg-amd64.img") version="Ubuntu 20.04" ;;
	*) version="UNKNOWN" ;;
    esac
    echo "|OS|${version}|"
}

function compute_cluster_k8s {
    local -r version=$(awk '/k8sVersion:/ {print $2}' ${ICNDIR}/deploy/cluster/values.yaml)
    echo "|K8s|${version}|"
}

function compute_cluster_cri {
    local -r version=$(awk '/containerdVersion:/ {print $2}' ${ICNDIR}/deploy/cluster/values.yaml)
    echo "|containerd|${version}|"
}

function compute_cluster_cni {
    echo "|Calico|${CALICO_VERSION}|"
}

function git_repository_tag {
    local -r source_yaml=$1
    awk '/tag:/ {print $2}' ${source_yaml}
}

function image_tag {
    local -r source_yaml=$1
    local -r image_name=$2
    awk -F: '/image:.*'"${image_name}"'/ {print $3}' ${source_yaml} | tr -d '"' 
}

function ref_tag {
    local -r kustomization_yaml=$1
    awk -F= '/?ref=/ {print $2}' ${kustomization_yaml} | tr -d "'"
}

function compute_cluster_addons {
    cat <<EOF
|Containerized Data Importer|${CDI_VERSION}|
|cert-manager|${CERT_MANAGER_VERSION}|
|CPU Manager for Kubernetes|${CPU_MANAGER_VERSION}|
|EMCO|$(git_repository_tag ${ICNDIR}/deploy/site/cluster-icn/emco-source.yaml)|
|Flux|${FLUX_VERSION}|
|Intel Network Adapter Virtual Function Driver Installer|$(image_tag ${ICNDIR}/deploy/iavf-driver-installer/icn/daemonset.yaml iavf-driver-installer)|
|Kata Containers|${KATA_VERSION}|
|KubeVirt|${KUBEVIRT_VERSION}|
|Multus|${MULTUS_VERSION}|
|Node Feature Discovery|$(ref_tag ${ICNDIR}/deploy/node-feature-discovery/icn/kustomization.yaml)|
|Nodus|${NODUS_VERSION}|
|Intel QAT Device Plugin|${QAT_VERSION}|
|Intel QAT Driver Installer|$(image_tag ${ICNDIR}/deploy/qat-driver-installer/icn/daemonset.yaml qat-driver-installer)|
|SR-IOV Network Operator|$(git_repository_tag ${ICNDIR}/deploy/sriov-network-operator/icn/source.yaml)|
EOF
}

function compute_cluster {
    table_header
    compute_cluster_os
    compute_cluster_k8s
    compute_cluster_cri
    compute_cluster_cni
    compute_cluster_addons
}

cat <<EOF >${ICNDIR}/doc/software-bom.md
<!-- Markdown generated from tools/software-bom.sh. DO NOT EDIT. -->

# Software BOM

## Jump server

$(jump_server)

## Compute cluster

$(compute_cluster)

EOF
