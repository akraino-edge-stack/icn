# Automatic installation script

`create_usb_bootable.sh` is a script to build an ubuntu ISO
with capability of no-attended installation. All the questiones
asked during installation are answered by the [preseed file](ubuntu/preseed/ubuntu-server.seed).
We copy the parent icn directory into the target ISO. Before copying
the icn directory, the collect scripts are called to collect files from
the Internet into icn directory. For example, to download deb packages,
to pull docker images, etc.

The collect scripts should accept one parameter. The parameter is the full path of the icn
directory. So that the collect scripts can know where to put the collected files at.
