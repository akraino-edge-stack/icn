#!/bin/bash

# usage: collect_sriov_yaml.sh [target]

set -ex

if [ $# -ne 1 ] ; then
    echo "Please input the target folder!"
    exit 0
fi

VER="0.1"
MKDIR_P="mkdir -p"
target=$1
temp=sriov_yaml

# copy to target
$MKDIR_P $temp
cp sriov-cni.yaml $temp/
cp sriovdp-daemonset.yaml $temp/
echo "#!/bin/bash" >> $temp/install.sh
echo "cat sriov-cni.yaml | kubectl apply -f -" >> $temp/install.sh
echo "cat sriovdp-daemonset.yaml | kubectl apply -f -" >> $temp/install.sh

if [ ! -d $target/yaml ]; then
    $MKDIR_P $target/yaml;
fi;

tar czvf $target/yaml/sriov_yaml-$VER.tar.gz $temp/

# clear
rm -rf $temp
