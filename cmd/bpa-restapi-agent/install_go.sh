#!/usr/bin/env bash
set -eu -o pipefail

if which go > /dev/null; then
    sudo apt-get -yq install golang-go
fi
