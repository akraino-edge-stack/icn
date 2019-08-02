# Integrated Cloud Native

Work in progress

For more information refer - https://wiki.akraino.org/pages/viewpage.action?pageId=11995140

## Build ISO

We should run the following commands on a fresh ubuntu 18.04

```bash
cd ~
mkdir -p workspace && cd workspace
git clone "https://gerrit.akraino.org/r/icn" # may need to switch the branch based on your case
sudo icn/tools/setup_build_machine.sh
sudo icn/tools/collect.sh
sudo icn/tools/create_usb_bootable.sh
```

The script builds an ISO based on the official ubuntu-18.04-server.iso. The generated ISO
is located at `workspace/icn-ubuntu-18.04.iso`.
All files under `icn` directory are copied into the ISO. During the installation of the ISO,
these files are copied to infra-local-controller under `/opt/icn`.

## How to use the ISO to bootstrap a infra-local-controller

1. We burn the ISO onto an USB strick.
2. We plug this USB into a server and press the power-on button. (choose boot from the USB strick)
3. The ubuntu 18.04 is supposed to be installed on the server, then it reboots automatically.
4. Now we can login the server with the default user/password of icn/icn
5. We can do anything we need here to install/configure/launch services.
