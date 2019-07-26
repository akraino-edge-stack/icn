#!/bin/bash

# usage: collect_qat_yaml.sh [target]

if [ $# -ne 1 ] ; then
    echo "Please input the target folder!"
    exit 0
fi

VER="0.1"
MKDIR_P="mkdir -p"
target=$1
temp=qat_yaml

# copy to target
mkdir $temp
cp qat_plugin_default_configmap.yaml $temp/
cp qat_plugin_privileges.yaml $temp/
echo "#!/bin/bash" >> $temp/install.sh
echo "cat qat_plugin_default_configmap.yaml | kubectl apply -f -" >> $temp/install.sh
echo "cat qat_plugin_privileges.yaml | kubectl apply -f -" >> $temp/install.sh

if [ ! -d $target/yaml ]; then
    $MKDIR_P $target/yaml;
fi;

tar czvf $target/yaml/qat_yaml-$VER.tar.gz $temp/

# clear
rm -rf $temp
