# Automatic installation script

`create_usb_bootable.sh` is a script to build an ubuntu ISO
with capability of no-attended installation. All the questiones
asked during installation are answered by the [preseed file](ubuntu/preseed/ubuntu-server.seed).
We copy the icn directory into the target ISO. Before running `create_usb_bootable.sh`
, the tools/collect.sh script is called to collect files from
the Internet into icn directory. For example, to download deb packages,
to pull docker images, etc.

Each component should has its own collect script. `tools/collect.sh` calls
each component collect script one by one. The componnet collect script must follow
several rules:

1. The name of component script should be `collect_xx.sh`
1. `set -ex` is needed in component script. So that the parent collect.sh can be awared of
the failure of component script.
1. The component script should accept one parameter, which is the icn directory. So that
the component script knows where to put the collected files.
1. Calling the component multiple times must not raise error.
1. Component scripts are supposed to run with root permission, we don't have to use `sudo`
in the component scripts.
