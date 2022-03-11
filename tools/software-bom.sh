#!/bin/bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname ${SCRIPTDIR})/env/lib"
ICNDIR="$(dirname ${SCRIPTDIR})"

source $LIBDIR/common.sh

function table_header {
    cat <<EOF
|Component|Link|Version|License|
|---|---|---|---|
EOF
}

function jump_server_os {
    case $(awk '/m.vm.box = / {print $3}' ${ICNDIR}/Vagrantfile | tr -d "'") in
	"intergratedcloudnative/ubuntu2004")
	    link="https://ubuntu.com/"
	    version="Ubuntu 20.04"
	    license="GPL-2.0"
	    ;;
	*)
	    link="UNKNOWN"
	    version="UNKNOWN"
	    license="UNKNOWN"
	    ;;
    esac
    echo "|OS|${link}|${version}|${license}|"
}

function kubespray_version {
    awk -F= '/KUBESPRAY_VERSION=/ {print $2}' ${ICNDIR}/deploy/kud/kud_bm_launch.sh
}

function jump_server_k8s {
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/kubespray-defaults/defaults/main.yaml | awk '/kube_version:/ {print $2}')
    echo "|Kubespray|https://github.com/kubernetes-sigs/kubespray|$(kubespray_version)|Apache-2.0|"
    echo "|K8s|https://kubernetes.io/|${version}|Apache-2.0|"
}

function jump_server_cri {
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/container-engine/docker/defaults/main.yml | awk '/docker_version:/ {print $2}' | tr -d "'")
    echo "|Docker|https://www.docker.com/|${version}|Apache-2.0|"
}

function jump_server_cni {
    # kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml:kube_network_plugin: flannel
    local -r version=$(curl -sL https://raw.githubusercontent.com/kubernetes-sigs/kubespray/v$(kubespray_version)/roles/download/defaults/main.yml | awk '/flannel_version:/ {print $2}' | tr -d '"')
    echo "|Flannel|https://github.com/flannel-io/flannel|${version}|Apache-2.0|"
}

function jump_server_addons {
    cat <<EOF
|Ironic|https://github.com/metal3-io/baremetal-operator|${BMO_VERSION}|Apache-2.0|
|cert-manager|https://cert-manager.io/|${CERT_MANAGER_VERSION}|Apache-2.0|
|Bare Metal Operator|https://github.com/metal3-io/baremetal-operator|${BMO_VERSION}|Apache-2.0|
|Cluster API|https://cluster-api.sigs.k8s.io/|${CAPI_VERSION}|Apache-2.0|
|Flux|https://fluxcd.io/|${FLUX_VERSION}|Apache-2.0|
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
	"focal-server-cloudimg-amd64.img")
	    link="https://ubuntu.com/"
	    version="Ubuntu 20.04"
	    license="GPL-2.0"
	    ;;
	*)
	    link="UNKNOWN"
	    version="UNKNOWN"
	    license="UNKNOWN"
	    ;;
    esac
    echo "|OS|${link}|${version}|${license}"
}

function compute_cluster_k8s {
    local -r version=$(awk '/k8sVersion:/ {print $2}' ${ICNDIR}/deploy/cluster/values.yaml)
    echo "|K8s|https://kubernetes.io/|${version}|Apache-2.0|"
}

function compute_cluster_cri {
    local -r version=$(awk '/containerdVersion:/ {print $2}' ${ICNDIR}/deploy/cluster/values.yaml)
    echo "|containerd|https://containerd.io/|${version}|Apache-2.0|"
}

function compute_cluster_cni {
    echo "|Calico|https://www.tigera.io/project-calico/|${CALICO_VERSION}|Apache-2.0|"
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

function iavf_driver_version {
    eval $(curl -sL https://raw.githubusercontent.com/onap/multicloud-k8s/${KUD_VERSION}/kud/deployment_infra/installers/entrypoint-iavf-driver-installer.sh | awk '/IAVF_DRIVER_VERSION/ {print; exit}')
    echo ${IAVF_DRIVER_VERSION}
}

function qat_driver_version {
    eval $(curl -sL https://raw.githubusercontent.com/onap/multicloud-k8s/${KUD_VERSION}/kud/deployment_infra/installers/entrypoint-qat-driver-installer.sh | awk '/QAT_DRIVER_VERSION/ {print; exit}')
    echo ${QAT_DRIVER_VERSION}
}

function compute_cluster_addons {
    cat <<EOF
|Containerized Data Importer|https://github.com/kubevirt/containerized-data-importer|${CDI_VERSION}|Apache-2.0|
|cert-manager|https://cert-manager.io/|${CERT_MANAGER_VERSION}|Apache-2.0|
|CPU Manager for Kubernetes|https://github.com/intel/CPU-Manager-for-Kubernetes|${CPU_MANAGER_VERSION}|Apache-2.0|
|EMCO|https://gitlab.com/project-emco|$(git_repository_tag ${ICNDIR}/deploy/site/cluster-emco-management/emco-source.yaml)|Apache-2.0|
|Flux|https://fluxcd.io/|${FLUX_VERSION}|Apache-2.0|
|Intel Network Adapter Linux Virtual Function Driver for Intel Ethernet Controller 700 and E810 Series|https://www.intel.com/content/www/us/en/download/18159/intel-network-adapter-linux-virtual-function-driver-for-intel-ethernet-controller-700-and-e810-series.html|$(iavf_driver_version)|GPL-2.0|
|Intel Network Adapter Virtual Function Driver Installer|https://gerrit.onap.org/r/#/admin/projects/multicloud/k8s|$(image_tag ${ICNDIR}/deploy/iavf-driver-installer/icn/daemonset.yaml iavf-driver-installer)|Apache-2.0|
|Istio|https://istio.io/|$(git_repository_tag ${ICNDIR}/deploy/site/cluster-addons/istio-source.yaml)|Apache-2.0|
|Kata Containers|https://katacontainers.io/|${KATA_VERSION}|Apache-2.0|
|KubeVirt|https://kubevirt.io/|${KUBEVIRT_VERSION}|Apache-2.0|
|Multus|https://github.com/k8snetworkplumbingwg/multus-cni|${MULTUS_VERSION}|Apache-2.0|
|Node Feature Discovery|https://github.com/kubernetes-sigs/node-feature-discovery|$(ref_tag ${ICNDIR}/deploy/node-feature-discovery/icn/kustomization.yaml)|Apache-2.0|
|Nodus|https://gerrit.akraino.org/r/admin/repos/icn/nodus|${NODUS_VERSION}|Apache-2.0|
|Intel QAT Driver for Linux for Intel Server Boards and Systems Based on Intel 62X Chipset|https://www.intel.com/content/www/us/en/download/19081/intel-quickassist-technology-intel-qat-driver-for-linux-for-intel-server-boards-and-systems-based-on-intel-62x-chipset.html|$(qat_driver_version)|GPL-2.0,BSD,OpenSSL,ZLib|
|Intel QAT Device Plugin|https://github.com/intel/intel-device-plugins-for-kubernetes|${QAT_VERSION}|Apache-2.0|
|Intel QAT Driver Installer|https://gerrit.onap.org/r/#/admin/projects/multicloud/k8s|$(image_tag ${ICNDIR}/deploy/qat-driver-installer/icn/daemonset.yaml qat-driver-installer)|Apache-2.0|
|SR-IOV Network Operator|https://github.com/k8snetworkplumbingwg/sriov-network-operator|$(git_repository_tag ${ICNDIR}/deploy/sriov-network-operator/icn/source.yaml)|Apache-2.0|
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
