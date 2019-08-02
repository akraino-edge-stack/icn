# Automatic installation script

`create_usb_bootable.sh` is a script to build an ubuntu ISO
with capability of no-attended installation. All the questiones
asked during installation are answered by the [preseed file](ubuntu/preseed/ubuntu-server.seed).
We copy the parent icn directory into the target ISO. Before running `create_usb_bootable.sh`
, the tools/collect.sh script is called to collect files from
the Internet into icn directory. For example, to download deb packages,
to pull docker images, etc.

The collect_*.sh scripts should accept one parameter. The parameter is the full path of the icn
directory. So that the collect_* scripts can know where to put the collected files at.
`set -ex` should set for each collect_*.sh, so that the parent collect.sh can be aware the error
in the collect_*.sh.
