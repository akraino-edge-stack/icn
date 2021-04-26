#!/usr/bin/env bash

#Local controller - Bootstrap cluster DHCP connection
export BS_DHCP_INTERFACE="eno3"
export BS_DHCP_INTERFACE_IP="172.31.1.1/24"

#Ironic Metal3 settings for provisioning network
export IRONIC_INTERFACE="enp4s0f3"

#Ironic Metal3 setting for IPMI LAN Network
export IRONIC_IPMI_INTERFACE="eno1"
export IRONIC_IPMI_INTERFACE_IP="10.10.110.25"
