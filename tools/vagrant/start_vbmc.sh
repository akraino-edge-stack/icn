#!/bin/bash
set -eu -o pipefail

if [[ -f ${HOME}/.vbmc/master.pid && $(ps -p $(cat ${HOME}/.vbmc/master.pid) 2>/dev/null) ]]; then
    echo virtualbmc is already started
else
    if [[ $(which apt-get 2>/dev/null) ]]; then
	DEBIAN_FRONTEND=noninteractive sudo apt-get install -y make libvirt-dev python3-pip
    elif [[ $(which yum) ]]; then
	sudo yum install -y make libvirt-devel python3-pip
    fi
    sudo python3 -m pip install libvirt-python virtualbmc
    mkdir -p ${HOME}/.vbmc
    cat <<EOF >${HOME}/.vbmc/virtualbmc.conf
[log]
logfile=${HOME}/.vbmc/virtualbmc.log
debug=True
[ipmi]
session_timout=20
EOF
    vbmcd
fi
