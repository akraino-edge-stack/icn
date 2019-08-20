#!/bin/bash
LIBDIR="$(dirname "$(dirname "$PWD")")"

source $LIBDIR/env/lib/common.sh

if [ ! -d $DOWNLOAD_PATH/multicloud-k8s ]; then
	pushd $DOWNLOAD_PATH
	git clone https://github.com/onap/multicloud-k8s.git
	popd
fi
