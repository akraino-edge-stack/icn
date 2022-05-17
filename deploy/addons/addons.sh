#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

function install_deps {
    apt-get install -y jq
}

function is_emco_ready {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    kubectl --kubeconfig=${cluster_kubeconfig} -n emco wait pod --all --for=condition=Ready --timeout=0s >/dev/null 2>&1
}

function register_emco_controllers {
    wait_for is_emco_ready
    local -r cluster_name=${CLUSTER_NAME:-icn}
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
  port: 30431
---
version: emco/v2
resourceContext:
  anchor: controllers
metadata:
  name: gac
spec:
  host: ${host}
  port: 30433
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
  port: 30432
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
  port: 30448
  type: "action"
  priority: 1
EOF
    emcoctl --config ${BUILDDIR}/${cluster_name}-config.yaml apply -f ${BUILDDIR}/${cluster_name}-controllers.yaml
}

function unregister_emco_controllers {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    emcoctl --config ${BUILDDIR}/${cluster_name}-config.yaml delete -f ${BUILDDIR}/${cluster_name}-controllers.yaml
}

function is_addon_ready {
    local -r addon=$1
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    if [[ $(kubectl --kubeconfig=${cluster_kubeconfig} -n kud get Kustomization/${addon} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; then
	return 1
    fi

    # Additional addon specific checks
    case ${addon} in
	"cpu-manager")
	    for node in $(kubectl --kubeconfig=${cluster_kubeconfig} -n kud get pods -l app=cmk-reconcile-ds-all -o jsonpath='{range .items[*]}{.spec.nodeName}{"\n"}{end}' | sort | uniq); do
		kubectl --kubeconfig=${cluster_kubeconfig} get cmk-nodereport ${node}
	    done
	    ;;
	"node-feature-discovery")
	    node_name=$(kubectl --kubeconfig=${cluster_kubeconfig} get nodes -o jsonpath='{range .items[*]}{.metadata.name} {.spec.taints[?(@.effect=="NoSchedule")].effect}{"\n"}{end}' | awk 'NF==1 {print $0;exit}')
	    kernel_version=$(kubectl --kubeconfig=${cluster_kubeconfig} get node ${node_name} -o jsonpath='{.metadata.labels.feature\.node\.kubernetes\.io/kernel-version\.major}')
	    [[ -n ${kernel_version} ]]
	    ;;
    esac
}

function test_openebs {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    kubectl --kubeconfig=${cluster_kubeconfig} apply -f ${SCRIPTDIR}/openebs-cstor.yaml
    kubectl --kubeconfig=${cluster_kubeconfig} wait pod hello-cstor-csi-disk-pod --for=condition=Ready --timeout=5m
    kubectl --kubeconfig=${cluster_kubeconfig} exec -it hello-cstor-csi-disk-pod -- cat /mnt/store/greet.txt
    kubectl --kubeconfig=${cluster_kubeconfig} delete -f ${SCRIPTDIR}/openebs-cstor.yaml
}

function is_vm_reachable {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    local -r node_port=$(kubectl --kubeconfig=${cluster_kubeconfig} -n kubevirt-test get service/test-vm-service -o jsonpath='{.spec.ports[].nodePort}')
    local -r node=$(kubectl -n metal3 get cluster/${cluster_name} -o jsonpath='{.spec.controlPlaneEndpoint.host}')
    sshpass -p testuser ssh testuser@${node} -p ${node_port} -- uptime
}

function test_kubevirt {
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    kubectl --kubeconfig=${cluster_kubeconfig} create ns kubevirt-test
    kubectl --kubeconfig=${cluster_kubeconfig} -n kubevirt-test create rolebinding psp:privileged-kubevirt-test --clusterrole=psp:privileged --group=system:serviceaccounts:kubevirt-test
    kubectl --kubeconfig=${cluster_kubeconfig} apply -f ${SCRIPTDIR}/kubevirt-test.yaml
    WAIT_FOR_TRIES=30
    wait_for is_vm_reachable
    kubectl --kubeconfig=${cluster_kubeconfig} delete -f ${SCRIPTDIR}/kubevirt-test.yaml
    kubectl --kubeconfig=${cluster_kubeconfig} -n kubevirt-test delete rolebinding psp:privileged-kubevirt-test
    kubectl --kubeconfig=${cluster_kubeconfig} delete ns kubevirt-test
}

function test_addons {
    install_deps

    # Create a temporary kubeconfig file for the tests
    local -r cluster_name=${CLUSTER_NAME:-icn}
    local -r cluster_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    clusterctl -n metal3 get kubeconfig ${cluster_name} >${cluster_kubeconfig}

    clone_kud_repository
    # The vFW test in EMCO v21.12 does not use KubeVirt, so patch the
    # KuD test and continue to use it
    pushd ${KUDPATH}
    patch -p1 --forward <${SCRIPTDIR}/plugin_fw_v2.patch || true
    popd

    pushd ${KUDPATH}/kud/tests
    failed_tests=""
    container_runtime=$(KUBECONFIG=${cluster_kubeconfig} kubectl get nodes -o jsonpath='{.items[].status.nodeInfo.containerRuntimeVersion}')
    if [[ "${container_runtime}" == "containerd://1.2.13" ]]; then
        # With containerd 1.2.13, the qat test container image fails to unpack.
        kud_tests="topology-manager-sriov:sriov-network multus:multus-cni ovn4nfv:nodus-network nfd:node-feature-discovery sriov-network:sriov-network cmk:cpu-manager"
    else
        kud_tests="topology-manager-sriov:sriov-network multus:multus-cni ovn4nfv:nodus-network nfd:node-feature-discovery sriov-network:sriov-network qat:qat-plugin cmk:cpu-manager"
    fi
    for kud_test in ${kud_tests}; do
        addon="${kud_test#*:}"
        test="${kud_test%:*}"
        if [[ ! -z ${addon} ]]; then
            wait_for is_addon_ready ${addon}
        fi
        KUBECONFIG=${cluster_kubeconfig} bash ${test}.sh || failed_tests="${failed_tests} ${test}"
    done
    # The plugin_fw_v2 test needs the EMCO controllers in place
    register_emco_controllers
    DEMO_FOLDER=${KUDPATH}/kud/demo KUBECONFIG=${cluster_kubeconfig} bash plugin_fw_v2.sh --external || failed_tests="${failed_tests} plugin_fw_v2"
    unregister_emco_controllers
    popd

    test_openebs || failed_tests="${failed_tests} openebs"
    test_kubevirt || failed_tests="${failed_tests} kubevirt"

    if [[ ! -z "$failed_tests" ]]; then
        echo "Test cases failed:${failed_tests}"
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
environment (default: "icn").  This should be the name of the
Cluster resource to execute the tests in.

Commands:
  test  - Test the addons
EOF
       ;;
esac
