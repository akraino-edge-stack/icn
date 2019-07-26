#!/bin/bash

function install_iavf_driver {
    local ifname=$1

    echo "Installing modules..."
    echo "Installing i40evf blacklist file..."
    mkdir -p "/etc/modprobe.d/"
    echo "blacklist i40evf" > "/etc/modprobe.d/iavf-blacklist-i40evf.conf"

    kver=`uname -a | awk '{print $3}'`
    install_mod_dir=/lib/modules/$kver/updates/drivers/net/ethernet/intel/iavf/
    echo "Installing driver in $install_mod_dir"
    mkdir -p $install_mod_dir
    cp iavf.ko $install_mod_dir

    echo "Installing kernel module i40evf..."
    depmod -a
    modprobe i40evf
    modprobe iavf

    echo "Enabling VF on interface $ifname..."
    echo "/sys/class/net/$ifname/device/sriov_numvfs"
    echo '8' > /sys/class/net/$ifname/device/sriov_numvfs
}

if [ $# -ne 1 ] ; then
  echo "Please input the ethernet interface to enable VF!"
else
  ifname=$1
  if [ ! -d /sys/class/net/$ifname/device ] ; then
    echo "${ifname} is not a valid sriov interface"
  else
    install_iavf_driver $ifname
  fi
fi
