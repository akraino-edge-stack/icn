#!/bin/bash

#set variables
#Todo include over all variables here
KUBE_VERSION=${KUBE_VERSION:-"v1.15.0"}
POD_NETWORK_CIDR=${POD_NETWORK_CIDR:-"10.244.0.0/16"}
PODMAN_CNI_CONFLIST=${PODMAN_CNI_CONFLIST:-"https://raw.githubusercontent.com/containers/libpod/v1.4.4/cni/87-podman-bridge.conflist"}
