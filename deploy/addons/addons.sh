#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

function register_emco_controllers {
    local -r cluster_name=${CLUSTER_NAME:-e2etest}
    local -r host=$(kubectl -n metal3 get cluster/${cluster_name} -o jsonpath='{.spec.controlPlaneEndpoint.host}')
    cat <<EOF >${BUILDDIR}/${cluster_name}-config.yaml
orchestrator:
  host: ${host}
  port: 30415
EOF
    cat <<EOF >${BUILDDIR}/${cluster_name}-controllers.yaml
---
version: emco/v2
resourceContext:
  anchor: controllers
metadata:
  name: rsync
spec:
  host: ${host}
  port: 30441
---
version: emco/v2
resourceContext:
  anchor: controllers
metadata:
  name: gac
spec:
  host: ${host}
  port: 30493
  type: "action"
  priority: 1
---
version: emco/v2
resourceContext:
  anchor: controllers
metadata:
  name: ovnaction
spec:
  host: ${host}
  port: 30473
  type: "action"
  priority: 1
---
version: emco/v2
resourceContext:
  anchor: controllers
metadata:
  name: dtc
spec:
  host: ${host}
  port: 30483
  type: "action"
  priority: 1
EOF
    emcoctl --config ${BUILDDIR}/${cluster_name}-config.yaml apply -f ${BUILDDIR}/${cluster_name}-controllers.yaml
}

function unregister_emco_controllers {
    local -r cluster_name=${CLUSTER_NAME:-e2etest}
    emcoctl --config ${BUILDDIR}/${cluster_name}-config.yaml delete -f ${BUILDDIR}/${cluster_name}-controllers.yaml
}

function test_addons {
    # Create a temporary kubeconfig file for the tests
    local -r cluster_name=${CLUSTER_NAME:-e2etest}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    clusterctl -n metal3 get kubeconfig ${cluster_name} >${cluster_kubeconfig}

    clone_kud_repository
    pushd ${KUDPATH}/kud/tests
    failed_kud_tests=""
    container_runtime=$(KUBECONFIG=${cluster_kubeconfig} kubectl get nodes -o jsonpath='{.items[].status.nodeInfo.containerRuntimeVersion}')
    # TODO Temporarily remove kubevirt from kud_tests below.  The
    # kubevirt self-test needs AllowTcpForwarding yes in
    # /etc/ssh/sshd_config which is currently disabled by the OS
    # security hardening.
    if [[ "${container_runtime}" == "containerd://1.2.13" ]]; then
        # With containerd 1.2.13, the qat test container image fails to unpack.
        kud_tests="topology-manager-sriov multus ovn4nfv nfd sriov-network cmk"
    else
        kud_tests="topology-manager-sriov multus ovn4nfv nfd sriov-network qat cmk"
    fi
    for test in ${kud_tests}; do
        KUBECONFIG=${cluster_kubeconfig} bash ${test}.sh || failed_kud_tests="${failed_kud_tests} ${test}"
    done
    # The plugin_fw_v2 test needs the EMCO controllers in place
    register_emco_controllers
    DEMO_FOLDER=${KUDPATH}/kud/demo KUBECONFIG=${cluster_kubeconfig} bash plugin_fw_v2.sh --external || failed_kud_tests="${failed_kud_tests} plugin_fw_v2"
    unregister_emco_controllers
    popd
    if [[ ! -z "$failed_kud_tests" ]]; then
        echo "Test cases failed:${failed_kud_tests}"
        exit 1
    fi
    echo "All test cases passed"

    rm ${cluster_kubeconfig}
}

case $1 in
    "test") test_addons ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

The "test" command looks for the CLUSTER_NAME variable in the
environment (default: "e2etest").  This should be the name of the
Cluster resource to execute the tests in.

Commands:
  test  - Test the addons
EOF
       ;;
esac
