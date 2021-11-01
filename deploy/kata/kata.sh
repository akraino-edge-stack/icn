#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

KATA_VERSION="2.1.0-rc0"
KATA_WEBHOOK_VERSION="2.1.0-rc0"

KATA_DEPLOY_URL="https://raw.githubusercontent.com/kata-containers/kata-containers/${KATA_VERSION}/tools/packaging/kata-deploy"
KATA_WEBHOOK_URL="https://raw.githubusercontent.com/kata-containers/tests/${KATA_WEBHOOK_VERSION}/kata-webhook"
KATA_WEBHOOK_DIR="/opt/src/kata_webhook"
KATA_WEBHOOK_RUNTIMECLASS="kata-clh"

# This may be used to update the in-place Kata YAML files from the
# upstream project.
function build_source {
    mkdir -p ${SCRIPTDIR}/base
    curl -sL ${KATA_DEPLOY_URL}/kata-rbac/base/kata-rbac.yaml -o ${SCRIPTDIR}/base/kata-rbac.yaml
    curl -sL ${KATA_DEPLOY_URL}/kata-deploy/base/kata-deploy.yaml -o ${SCRIPTDIR}/base/kata-deploy.yaml
    curl -sL ${KATA_DEPLOY_URL}/runtimeclasses/kata-runtimeClasses.yaml -o ${SCRIPTDIR}/base/kata-runtimeClasses.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd
}

case $1 in
    "build-source") build_source ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree Kata YAML files
EOF
       ;;
esac
