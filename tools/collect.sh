#!/usr/bin/env bash


set -ex

SCRIPT_PATH=`realpath $0`
TOOL_PATH=`dirname "$SCRIPT_PATH"`
ICN_PATH=`dirname $TOOL_PATH`
# Get into workspace directory, we run every following command from the workspace directory
cd $ICN_PATH/../

mkdir -p $ICN_PATH/apt/deb/

# Call scripts to collect everything from Internet,
# all the collected files need to be put under ICN_PATH
for collect_sh in `find icn/ -name collect_*.sh`
do
  collect_parent=`dirname $collect_sh`
  pushd $collect_parent
    bash `basename $collect_sh` $ICN_PATH
  popd
done
