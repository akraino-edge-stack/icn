#!/usr/bin/env bash

#Ironic Metal3 settings for provisioning network
export IRONIC_INTERFACE="enp4s0f3"

#Ironic Metal3 setting to disable DHCP server for provisioning network
#The DHCP server is not necessary when all machines can be provisioned with virtual media
export IRONIC_ENABLE_DHCP="yes"

#Use a registry mirror for downloading container images
export DOCKER_REGISTRY_MIRRORS=""
