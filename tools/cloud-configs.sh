!/bin/bash

# This script is called by cloud-init on worker nodes
# What does this script do:
# 1. Copy qat driver tarball and sriov tarball from share folder
# 2. Extract the tarball and run install.sh to install the drivers

# Need a variable named $SHARE_FOLDER to indicate the share folder location

MODULES_LIST="qat_driver sriov_driver"
VER="0.1"
SHARE_FOLDER=${SHARE_FOLDER:-"package"}

for module in $MODULES_LIST; do
    filename=$module-$VER.tar.gz
    if [ ! -e $filename ]; then
        if [ ! -e $SHARE_FOLDER/$filename ]; then
        echo "Cannot install module $module ..."
        continue
    else
            cp $SHARE_FOLDER/$filename .
        fi
    fi

    tar xvzf $filename
    if [ -d $module ]; then
        echo "Installing module $module ..."
    pushd $module
        bash ./install.sh
        popd
    rm -rf $module
    fi
done

