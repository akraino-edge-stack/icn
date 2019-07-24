# Integrated Cloud Native

Work in progress

For more information refer - https://wiki.akraino.org/pages/viewpage.action?pageId=11995140

## Build ISO

`sudo tools/create_usb_bootable.sh`

The script builds the ISO based on the official ubuntu-18.04-server.iso.
All files under `icn` directory are copied into the ISO. During the installation of the ISO,
these files are copied to target OS under `/bootstrap`
