#!/bin/bash
set -eu -o pipefail

if [[ -f ${HOME}/.vbmc/master.pid && $(ps -p $(cat ${HOME}/.vbmc/master.pid) 2>/dev/null) ]]; then
    kill $(cat ${HOME}/.vbmc/master.pid)
    echo Stopped virtualbmc
fi
