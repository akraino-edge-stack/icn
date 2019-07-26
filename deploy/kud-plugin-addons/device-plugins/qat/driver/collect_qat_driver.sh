#!/bin/bash

# usage: collect_qat_driver.sh [target]

if [ $# -ne 1 ] ; then
    echo "Please input the target folder!"
    exit 0
fi

VER="0.1"
MKDIR_P="mkdir -p"
target=$1
package=qat1.7.l.4.6.0-00025

# download driver source package
if [ ! -e $package.tar.gz ]; then
    wget https://01.org/sites/default/files/downloads/$package.tar.gz
fi

# compile
mkdir $package	
tar xzvf $package.tar.gz -C $package
pushd `pwd`
cd $package
./configure --enable-icp-sriov=host
make
popd

# copy to target
mkdir qat_driver
cp -r $package/build/* qat_driver/
cp install_qat.sh qat_driver/install.sh
cp qat qat_driver/

if [ ! -d $target/driver ]; then
    $MKDIR_P $target/driver;
fi;

tar czvf $target/driver/qat_driver-$VER.tar.gz qat_driver/

# clear
rm -rf $package
rm -rf qat_driver
rm $package.tar.gz
