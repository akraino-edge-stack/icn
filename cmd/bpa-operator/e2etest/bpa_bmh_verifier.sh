#!/usr/bin/env bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh

CLUSTER_NAME=test-bmh-cluster
ADDONS_NAMESPACE=kud

function emco_ready {
    KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n emco wait pod --all --for=condition=Ready --timeout=0s 1>/dev/null 2>/dev/null
}

function emcoctl_apply {
    [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply -f $@ -v values.yaml |
             awk '/Response Code:/ {code=$3} END{print code}') =~ 2.. ]]
}

function emcoctl_delete {
    [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh delete -f $@ -v values.yaml |
             awk '/Response Code:/ {code=$3} END{print code}') =~ 404 ]]
}

function emcoctl_instantiate {
    [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply projects/kud/composite-apps/$@/v1/deployment-intent-groups/deployment/instantiate |
             awk '/Response Code:/ {code=$3} END{print code}') =~ 2.. ]]
}

function emcoctl_terminate {
    [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply projects/kud/composite-apps/$@/v1/deployment-intent-groups/deployment/terminate |
             awk '/Response Code:/ {code=$3} END{print code}') =~ 2.. ]]
}

function emcoctl {
    local -r op=$1
    shift

    local -r interval=2
    for ((try=0;try<600;try+=${interval})); do
        if emco_ready; then break; fi
        echo "$(date +%H:%M:%S) - Waiting for emco"
        sleep ${interval}s
    done

    for ((;try<600;try+=${interval})); do
	case ${op} in
	    "apply") if emcoctl_apply $@; then return 0; fi ;;
	    "delete") if emcoctl_delete $@; then return 0; fi ;;
	    "instantiate") if emcoctl_instantiate $@; then return 0; fi ;;
	    "terminate") if emcoctl_terminate $@; then return 0; fi ;;
	esac
        echo "$(date +%H:%M:%S) - Waiting for emcoctl ${op} $@"
        sleep ${interval}s
    done

    return 1
}

function addons_instantiated {
    KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} wait pod -l app.kubernetes.io/instance=r1 --for=condition=Ready --timeout=0s 1>/dev/null 2>/dev/null
}

function addons_terminated {
    [[ $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get pod -l app.kubernetes.io/instance=r1 --no-headers 2>/dev/null | wc -l) == 0 ]]
}

function networks_instantiated {
    local -r count=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get sriovnetworknodestate --no-headers 2>/dev/null | wc -l)
    local -r succeeded=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get sriovnetworknodestate -o jsonpath='{range .items[*]}{.status.syncStatus}{"\n"}{end}' 2>/dev/null | grep "Succeeded" | wc -l)
    [[ $count == $succeeded ]]
}

function networks_terminated {
    # The syncStatus will be the same whether we are instantiating or terminating an SR-IOV network
    networks_instantiated
}

function kubevirt_instantiated {
    [[ $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get kubevirt -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep "Deployed" | wc -l) == 1 ]]
    [[ $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get cdi -o jsonpath='{range .items[*]}{.status.phase}{"\n"}{end}' 2>/dev/null | grep "Deployed" | wc -l) == 1 ]]
}

function kubevirt_terminated {
    [[ $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get kubevirt --no-headers 2>/dev/null | wc -l) == 0 ]]
    [[ $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get cdi --no-headers 2>/dev/null | wc -l) == 0 ]]
}

if [[ $1 == "provision" ]]; then
    kubectl create -f e2etest/test_bmh_provisioning_cr.yaml
    sleep 5

    #Check Status of kud job pod
    status="Running"

    while [[ $status == "Running" ]]
    do
	echo "KUD install job still running"
	sleep 2m
	stats=$(kubectl get pods |grep -i kud-${CLUSTER_NAME})
	status=$(echo $stats | cut -d " " -f 3)
    done

    #Print logs of Job Pod
    jobPod=$(kubectl get pods|grep kud-${CLUSTER_NAME})
    podName=$(echo $jobPod | cut -d " " -f 1)
    printf "\nNow Printing Job pod logs\n"
    kubectl logs $podName

    if [[ $status == "Completed" ]];
    then
	printf "KUD Install Job completed\n"
	printf "Checking cluster status\n"

	source ../../env/lib/common.sh
	CLUSTER_KUBECONFIG=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/admin.conf
	APISERVER=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')
	TOKEN=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl get secret $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode)
	if ! call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure;
	then
	    printf "\nKubernetes Cluster Install did not complete successfully\n"
	    exit 1
	else
	    printf "\nKubernetes Cluster Install was successful\n"
	fi

    else
	printf "KUD Install Job failed\n"
	exit 1
    fi

    #Apply addons
    printf "Applying KUD addons\n"
    pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
    emcoctl apply 00-controllers.yaml
    emcoctl apply 01-cluster.yaml
    emcoctl apply 02-project.yaml
    emcoctl apply 03-addons-app.yaml
    popd

    #Instantiate addons
    emcoctl instantiate addons
    wait_for addons_instantiated
    emcoctl instantiate networks
    wait_for networks_instantiated
    emcoctl instantiate kubevirt
    wait_for kubevirt_instantiated

    #Test addons
    printf "Testing KUD addons\n"
    pushd /opt/kud/multi-cluster/addons/tests
    failed_kud_tests=""
    container_runtime=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl get nodes -o jsonpath='{.items[].status.nodeInfo.containerRuntimeVersion}')
    if [[ "${container_runtime}" == "containerd://1.2.13" ]]; then
	#With containerd 1.2.13, the qat test container image fails to unpack.
	kud_tests="topology-manager-sriov kubevirt multus ovn4nfv nfd sriov-network cmk"
    else
	kud_tests="topology-manager-sriov kubevirt multus ovn4nfv nfd sriov-network qat cmk"
    fi
    for test in ${kud_tests}; do
	KUBECONFIG=${CLUSTER_KUBECONFIG} bash ${test}.sh || failed_kud_tests="${failed_kud_tests} ${test}"
    done
    KUBECONFIG=${CLUSTER_KUBECONFIG} DEMO_FOLDER=${PWD} PATH=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts:${PATH} bash plugin_fw_v2.sh --external || failed_kud_tests="${failed_kud_tests} plugin_fw_v2"
    if [[ ! -z "$failed_kud_tests" ]]; then
	printf "Test cases failed:${failed_kud_tests}\n"
	exit 1
    fi
    popd
    printf "All test cases passed\n"
elif [[ $1 == "teardown" ]]; then
    CLUSTER_KUBECONFIG=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/admin.conf
    #Tear down setup
    printf "\n\nBeginning BMH E2E Test Teardown\n\n"
    emcoctl terminate kubevirt
    wait_for kubevirt_terminated
    emcoctl terminate networks
    wait_for networks_terminated
    emcoctl terminate addons
    wait_for addons_terminated
    pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
    emcoctl delete 03-addons-app.yaml
    emcoctl delete 02-project.yaml
    emcoctl delete 01-cluster.yaml
    emcoctl delete 00-controllers.yaml
    popd
    kubectl delete -f e2etest/test_bmh_provisioning_cr.yaml
    kubectl delete job kud-${CLUSTER_NAME}
    kubectl delete --ignore-not-found=true configmap ${CLUSTER_NAME}-configmap
    rm -rf /opt/kud/multi-cluster/${CLUSTER_NAME}
    rm -rf /opt/kud/multi-cluster/addons
    make delete
fi
