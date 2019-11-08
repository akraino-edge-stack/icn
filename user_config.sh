#!/bin/bash

#Local controller - Bootstrap cluster DHCP connection
BS_DHCP_INTERFACE=${BS_DHCP_INTERFACE:-"ens513f0"}
BS_DHCP_INTERFACE_IP=${BS_DHCP_INTERFACE_IP:-"172.31.1.1/24"}

#Ironic Metal3 settings for provisioning network
IRONIC_INTERFACE=${IRONIC_INTERFACE:-"enp4s0f1"}

#Ironic Metal3 setting for IPMI LAN Network
IRONIC_IPMI_INTERFACE=${IRONIC_IPMI_INTERFACE:-"enp4s0f0"}
IRONIC_IPMI_INTERFACE_IP=${IRONIC_IPMI_INTERFACE_IP:-"10.10.110.20"}
