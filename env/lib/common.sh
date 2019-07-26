#!/bin/bash

#supported OS version
UBUNTU_BIONIC=${UBUNTU_BIONIC:-Ubuntu 18.04.2 LTS}

#offline mode variable
DOWNLOAD_PATH=${DOWNLOAD_PATH:-/opt/icn/}
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


#Ironic variables
IRONIC_IMAGE=${IRONIC_IMAGE:-"quay.io/metal3-io/ironic:master"}
IRONIC_INSPECTOR_IMAGE=${IRONIC_INSPECTOR_IMAGE:-"quay.io/metal3-io/ironic-inspector"}
IRONIC_BAREMETAL_IMAGE=${IRONIC_BAREMETAL_IMAGE:-"quay.io/metal3-io/baremetal-operator:master"}
IRONIC_BAREMETAL_SOCAT_IMAGE=${IRONIC_BAREMETAL_SOCAT_IMAGE:-"alpine/socat:latest"}

IRONIC_DATA_DIR=${IRONIC_DATA_DIR:-"/opt/ironic"}
#IRONIC_PROVISIONING_INTERFACE is required to be provisioning, don't change it
IRONIC_PROVISIONING_INTERFACE=${IRONIC_PROVISIONING_INTERFACE:-"provisioning"}
IRONIC_IPMI_INTERFACE=${IRONIC_IPMI_INTERFACE:-"eno1"}
IRONIC_PROVISIONING_INTERFACE_IP=${IRONIC_PROVISIONING_INTERFACE_IP:-"172.22.0.1"}
IRONIC_IPMI_INTERFACE_IP=${IRONIC_IPMI_INTERFACE_IP:-"172.31.1.9"}
BM_IMAGE_URL=${BM_IMAGE_URL:-"https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"}
BM_IMAGE=${BM_IMAGE:-"bionic-server-cloudimg-amd64.img"}

#Todo change into nodes list in json pattern
COMPUTE_NODE_NAME=${COMPUTE_NODE_NAME:-"el-100-node-01"}
COMPUTE_IPMI_ADDRESS=${COMPUTE_IPMI_ADDRESS:-"172.31.1.17"}
COMPUTE_IPMI_USER=${COMPUTE_IPMI_USER:-"ryeleswa"}
COMPUTE_IPMI_PASSWORD=${COMPUTE_IPMI_PASSWORD:-"changeme1"}
COMPUTE_NODE_FQDN=${COMPUTE_NODE_FQDN:-"node01.akraino.org"}
#COMPUTE_NODE_HOSTNAME=${COMPUTE_NODE_HOSTNAME:-"node01"}
COMPUTE_NODE_PASSWORD=${COMPUTE_NODE_PASSWORD:-"mypasswd"}
