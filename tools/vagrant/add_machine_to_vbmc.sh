#!/bin/bash
set -eu -o pipefail

site=$1
name=$2
port=$3

vbmc --no-daemon add ${site}-${name} --port ${port} --libvirt-uri "qemu:///system?&no_verify=1&no_tty=1"
vbmc --no-daemon start ${site}-${name}
