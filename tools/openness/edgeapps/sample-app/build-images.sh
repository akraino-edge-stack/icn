#!/usr/bin/env bash
set -eux -o pipefail

source ../../_common.sh

# install_deps() - Install dependencies required for build eaa image
function install_deps {
    if ! $(go version &>/dev/null); then
        _install_go
    fi

    if ! $(docker version &>/dev/null); then
        _install_docker
    fi
}

install_deps
mkdir -p /tmp/openness
cp ./BUILD-SAMPLE-APP-IMAGE.patch /tmp/openness/
cd /tmp/openness
wget https://github.com/open-ness/edgeapps/archive/openness-19.12.01_1.tar.gz
tar xvf openness-19.12.01_1.tar.gz
cd edgeapps-openness-19.12.01_1
patch -p1 < ../BUILD-SAMPLE-APP-IMAGE.patch
cd sample-app
make
make build-docker
docker tag consumer:1.0 integratedcloudnative/consumer:1.0
docker tag producer:1.0 integratedcloudnative/producer:1.0
cd /tmp
rm -rf /tmp/openness
