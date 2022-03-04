#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

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
    rm -f ${SCRIPTDIR}/base/kustomization.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd
}

function deploy_webhook {
    local -r cluster_name=$1
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"

    # Note that the webhook-registration.yaml.tpl file is fetched here
    # but webhook-registration.yaml is deployed: this is intentional,
    # create-certs.sh takes care of converting the .yaml.tpl into the
    # .yaml file
    mkdir -p ${BUILDDIR}/webhook/base/deploy
    curl -sL ${KATA_WEBHOOK_URL}/common.bash -o ${BUILDDIR}/webhook/base/common.bash
    curl -sL ${KATA_WEBHOOK_URL}/create-certs.sh -o ${BUILDDIR}/webhook/base/create-certs.sh
    curl -sL ${KATA_WEBHOOK_URL}/deploy/webhook-registration.yaml.tpl -o ${BUILDDIR}/webhook/base/deploy/webhook-registration.yaml.tpl
    curl -sL ${KATA_WEBHOOK_URL}/deploy/webhook.yaml -o ${BUILDDIR}/webhook/base/deploy/webhook.yaml

    chmod +x ${BUILDDIR}/webhook/base/create-certs.sh
    sed 's/value: kata/value: ${KATA_WEBHOOK_RUNTIMECLASS}/g' ${BUILDDIR}/webhook/base/deploy/webhook.yaml | tee ${BUILDDIR}/webhook/base/deploy/webhook-${KATA_WEBHOOK_RUNTIMECLASS}.yaml
    pushd ${BUILDDIR}/webhook/base && ./create-certs.sh && popd

    cat <<EOF >${BUILDDIR}/webhook/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- deploy/webhook-certs.yaml
- deploy/webhook-registration.yaml
- deploy/webhook-${KATA_WEBHOOK_RUNTIMECLASS}.yaml
EOF

    kustomize build ${BUILDDIR}/webhook/base | KUBECONFIG=${cluster_kubeconfig} kubectl apply -f -
}

function clean_webhook {
    local -r cluster_name=$1
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"

    kustomize build ${BUILDDIR}/webhook/base | KUBECONFIG=${cluster_kubeconfig} kubectl delete -f -
}

function is_kata_deployed {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    kubectl --kubeconfig=${cluster_kubeconfig} get runtimeclass/kata-qemu
}

function test_kata {
    # Create a temporary kubeconfig file for the tests
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    clusterctl -n metal3 get kubeconfig ${cluster_name} >${cluster_kubeconfig}

    # Ensure that Kata has been deployed first
    WAIT_FOR_TRIES=30
    wait_for is_kata_deployed

    deploy_webhook ${cluster_name}
    clone_kud_repository
    pushd ${KUDPATH}/kud/tests
    failed_kud_tests=""
    KUBECONFIG=${cluster_kubeconfig} bash kata.sh || failed_kud_tests="${failed_kud_tests} kata"
    popd
    clean_webhook ${cluster_name}
    if [[ ! -z "$failed_kud_tests" ]]; then
        echo "Test cases failed:${failed_kud_tests}"
        exit 1
    fi
    echo "All test cases passed"

    rm ${cluster_kubeconfig}
}

case $1 in
    "build-source") build_source ;;
    "test") test_kata ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

The "test" command looks for the CLUSTER_NAME variable in the
environment (default: "icn").  This should be the name of the
Cluster resource to execute the tests in.

Commands:
  build-source  - Rebuild the in-tree Kata YAML files
  test          - Test Kata
EOF
       ;;
esac
