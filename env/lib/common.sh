#!/bin/bash

#set variables
#Todo include over all variables here
KUBE_VERSION=${KUBE_VERSION:-"v1.15.0"}
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"10.244.0.0/16"}
PODMAN_CNI_CONFLIST=${PODMAN_CNI_CONFLIST:-"https://raw.githubusercontent.com/containers/libpod/v1.4.4/cni/87-podman-bridge.conflist"}

#Ironic variables
IRONIC_IMAGE=${IRONIC_IMAGE:-"quay.io/metal3-io/ironic:master"}
IRONIC_INSPECTOR_IMAGE=${IRONIC_INSPECTOR_IMAGE:-"quay.io/metal3-io/ironic-inspector"}
IRONIC_DATA_DIR=${IRONIC_DATA_DIR:-"/opt/ironic"}
IRONIC_PROVISIONING_INTERFACE=${IRONIC_PROVISIONING_INTERFACE:-"provisioning"}
IRONIC_IPMI_INTERFACE=${IRONIC_IPMI_INTERFACE:-"eno1"}
IRONIC_PROVISIONING_INTERFACE_IP=${IRONIC_PROVISIONING_INTERFACE_IP:-"172.22.0.1"}
IRONIC_IPMI_INTERFACE_IP=${IRONIC_IPMI_INTERFACE_IP:-"172.31.1.9"}
BM_IMAGE_URL=${BM_IMAGE_URL:-"https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"}
BM_IMAGE=${BM_IMAGE:-"bionic-server-cloudimg-amd64.img"}
