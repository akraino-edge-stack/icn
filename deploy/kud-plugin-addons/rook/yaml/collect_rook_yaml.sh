#!/bin/bash

# usage: collect_rook_yaml.sh [target]

set -ex

if [ $# -ne 1 ] ; then
    echo "Please input the target folder!"
    exit 0
fi

VER="0.1"
MKDIR_P="mkdir -p"
target=$1
temp=rook_yaml

# copy to target
$MKDIR_P $temp
cp rook-common.yaml $temp/
cp rook-operator-with-csi.yaml $temp/
cp rook-ceph-cluster.yaml $temp/
cp rook-toolbox.yaml $temp/
cp -rf ./csi/ $temp/
cp -rf ./test/ $temp/
cp install.sh $temp/

if [ ! -d $target/yaml ]; then
    $MKDIR_P $target/yaml;
fi;

tar czvf $target/yaml/rook_yaml-$VER.tar.gz $temp/

# clear
rm -rf $temp
