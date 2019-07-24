#!/usr/bin/env bash

set -ex

TOOLDIR=`dirname "$0"`
BASEDIR=`dirname $TOOLDIR`
cd $BASEDIR
mkdir -p .build
cd .build

if [ ! -f "ubuntu-18.04.2-server-amd64.iso" ];then
  wget "http://cdimage.ubuntu.com/ubuntu/releases/18.04/release/ubuntu-18.04.2-server-amd64.iso"
else
  echo "Not download official ISO, using existing one"
fi

mkdir -p iso
mount ubuntu-18.04.2-server-amd64.iso iso
rm -rf ubuntu
cp -r iso ubuntu
umount iso

cp -rf ../tools/ubuntu/* ubuntu/
mkdir ubuntu/bootstrap
ls .. | xargs -i cp -r ../{} ubuntu/bootstrap/

mkisofs -R -J -T -v -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat -o ../icn-ubuntu-18.04.iso ubuntu/
