#!/bin/bash
set -eu -o pipefail

index=$1
site=$2
name=$3

vbmc --no-daemon add ${site}-${name} --port $((6230+index-1)) --libvirt-uri "qemu:///system?&no_verify=1&no_tty=1"
vbmc --no-daemon start ${site}-${name}
