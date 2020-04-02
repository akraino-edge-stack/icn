#!/usr/bin/env bash

set -ex

source ../_common.sh

# install_deps() - Install dependencies required for build eaa image
function install_deps {
    if ! $(go version &>/dev/null); then
        _install_go
    fi

    if ! $(docker version &>/dev/null); then
        _install_docker
    fi

    if ! $(patch -v &>/dev/null); then
        apt-get update && apt-get install patch
    fi
}

install_deps
mkdir -p /tmp/openness
cp ./BUILD-EAA-IMAGE.patch /tmp/openness/
cd /tmp/openness
wget https://github.com/open-ness/edgenode/archive/openness-19.12.01.tar.gz
tar xvf openness-19.12.01.tar.gz
cd edgenode-openness-19.12.01
patch -p1 < ../BUILD-EAA-IMAGE.patch
GOOS=linux go build -o "./build/eaa/eaa" ./cmd/eaa
cd build/eaa
docker build -t integratedcloudnative/eaa:1.0 .
cd /tmp
rm -rf /tmp/openness
