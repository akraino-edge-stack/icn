#!/usr/bin/env bash
set -eux -o pipefail

SCRIPT_PATH=`realpath $0`
TOOL_PATH=`dirname "$SCRIPT_PATH"`
ICN_PATH=`dirname $TOOL_PATH`
# Get into workspace directory, we run every following command from the workspace directory
cd $ICN_PATH/../

mkdir -p build

if [ ! -f "build/ubuntu-18.04.2-server-amd64.iso" ];then
    curl "http://old-releases.ubuntu.com/releases/18.04.2/ubuntu-18.04.2-server-amd64.iso" \
    -o build/ubuntu-18.04.2-server-amd64.iso
else
    echo "Not download official ISO, using existing one"
fi

mkdir -p build/iso
mount build/ubuntu-18.04.2-server-amd64.iso build/iso
rm -rf build/ubuntu
cp -r build/iso build/ubuntu
umount build/iso

cp -rf icn/tools/ubuntu/* build/ubuntu/
cp -rf icn build/ubuntu/

mkisofs -R -J -T -v -no-emul-boot -boot-load-size 4 -boot-info-table \
    -b isolinux/isolinux.bin -c isolinux/boot.cat -o icn-ubuntu-18.04.iso build/ubuntu/
