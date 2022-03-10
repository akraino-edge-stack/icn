#!/bin/bash
set -eu -o pipefail

listen_ip=$1

if [[ -f ${HOME}/.sushy/emulator.pid ]]; then
    if ps -p $(cat ${HOME}/.sushy/emulator.pid); then
       kill $(cat ${HOME}/.sushy/emulator.pid)
    fi
    rm ${HOME}/.sushy/emulator.pid
    echo Stopped sushy-emulator
    dev=$(ip -o addr show to ${listen_ip} | awk '{print $2}')
    sudo ip route del 172.22.0.0/24 dev ${dev}
fi
