#!/bin/bash

# usage: collect_optane_yaml.sh

set -ex

# deploy docker hub

# kubectl label node <your node> storage=pmem

# deploy pmem-csi and applications
# select two mode: lvm and direct
# kubectl create -f pmem-csi-lvm.yaml
# kubectl create -f pmem-csi-direct.yaml
