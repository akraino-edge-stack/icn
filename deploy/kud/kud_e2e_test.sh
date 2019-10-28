#!/bin/bash

function _get_kud_ {
  echo " Download KuD project.. "
  git clone "git clone "https://gerrit.onap.org/r/multicloud/k8s""
  pushd $kud_folder/config
  mv default.yml samples/ha.yml
  mv samples/pdf.yml.aio ../config/default.yml
  popd
  pushd $kud_folder
  ./setup.sh -p libvirt
  #Changing the default value to enable test cases in KuD
  sed -i -e 's/testing_enabled=${KUD_ENABLE_TESTS:-false}/testing_enabled=${KUD_ENABLE_TESTS:-true}/g' installer.sh
  #bring up the VMs
  sudo vagrant up && sudo vagrant up installer 

}

#configuration values
kud_folder=~/icn/k8s/kud/hosting_providers/vagrant
kud_inventory_folder=$kud_folder/inventory

_get_kud_
