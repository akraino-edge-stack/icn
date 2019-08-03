#!/bin/bash

# usage: collect_sriov_driver.sh [target]

set -ex

if [ $# -ne 1 ] ; then
    echo "Please input the target folder!"
    exit 0
fi

VER="0.1"
MKDIR_P="mkdir -p"
target=$1
package=iavf-3.7.34

# download driver source package
if [ ! -e /tmp/$package.tar.gz ]; then
    wget -P /tmp https://downloadmirror.intel.com/28943/eng/$package.tar.gz
fi
cp /tmp/$package.tar.gz .

# compile
tar xzvf $package.tar.gz
pushd `pwd`
cd $package/src
make
popd

# copy to target
$MKDIR_P sriov_driver
cp $package/src/iavf.ko sriov_driver/
cp install_iavf_drivers.sh sriov_driver/install.sh

if [ ! -d $target/driver ]; then
    $MKDIR_P $target/driver;
fi;

tar czvf $target/driver/sriov_driver-$VER.tar.gz sriov_driver/

# clear
rm -rf $package
rm -rf sriov_driver
rm $package.tar.gz
