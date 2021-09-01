#!/usr/bin/env bash
set -eu -o pipefail

CLUSTER_NAME=test-bmh-cluster
ADDONS_NAMESPACE=kud

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

function emcoctl_apply {
    # Workaround known issue with emcoctl resource instantation by retrying
    # until a 2xx is received.
    try=0
    until [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply -f $@ -v values.yaml  |
                   awk '/Response Code:/ {code=$3} END{print code}') =~ 2.. ]]; do
        if [[ $try -lt 10 ]]; then
            echo "Waiting for KUD addons to instantiate"
            sleep 1s
        else
            return 1
        fi
        try=$((try + 1))
    done
    return 0
}

function emcoctl_delete {
    # Workaround known issue with emcoctl resource deletion by retrying
    # until a 404 is received.
    until [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh delete -f $@ -v values.yaml |
                   awk '/Response Code:/ {code=$3} END{print code}') =~ 404 ]]; do
        echo "Waiting for KUD addons to terminate"
        sleep 1s
    done
}

function wait_for_addons_ready {
    #Wait for addons to be ready
    # The deployment intent group status reports instantiated before all
    # Pods are ready, so wait for the instance label (.spec.version) of
    # the deployment intent group instead.
    status="Pending"
    for try in {0..19}; do
	printf "Waiting for KUD addons to be ready\n"
	sleep 30s
	if KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} wait pod -l app.kubernetes.io/instance=r1 --for=condition=Ready --timeout=0s 2>/dev/null >/dev/null; then
            status="Ready"
            break
	fi
    done
    [[ $status == "Ready" ]]
}

#Install addons
printf "Installing KUD addons\n"
pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
emcoctl_apply 00-controllers.yaml
emcoctl_apply 01-cluster.yaml
emcoctl_apply 02-project.yaml
emcoctl_apply 03-addons-app.yaml
popd
wait_for_addons_ready

#Workaround for sriov+kubevirt issue on single-node clusters
# The issue is kubevirt creates a PodDisruptionBudget that prevents
# sriov from succesfully draining the node.  The workaround is to
# temporarily scale down the kubevirt operator while the drain occurs.
KUBEVIRT_OP_REPLICAS=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} get deployments/r1-kubevirt-operator -o jsonpath='{.spec.replicas}')
KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} scale deployments/r1-kubevirt-operator --replicas=0

#Install addon resources
printf "Installing KUD addon resources\n"
pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
emcoctl_apply 04-addon-resources-app.yaml
popd
wait_for_addons_ready

#Workaround for sriov+kubevirt issue on single-node clusters
# Scale the kubevirt operator back up and wait things to be ready
# again.
KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl wait nodes --for=condition=Ready --all
KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl -n ${ADDONS_NAMESPACE} scale deployments/r1-kubevirt-operator --replicas=${KUBEVIRT_OP_REPLICAS}
wait_for_addons_ready

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

#Tear down setup
printf "\n\nBeginning BMH E2E Test Teardown\n\n"
# Workaround known issue with emcoctl resource deletion by retrying
# until a 404 is received.
pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
emcoctl_delete 04-addon-resources-app.yaml
emcoctl_delete 03-addons-app.yaml
emcoctl_delete 02-project.yaml
emcoctl_delete 01-cluster.yaml
emcoctl_delete 00-controllers.yaml
popd
kubectl delete -f e2etest/test_bmh_provisioning_cr.yaml
kubectl delete job kud-${CLUSTER_NAME}
kubectl delete --ignore-not-found=true configmap ${CLUSTER_NAME}-configmap
rm -rf /opt/kud/multi-cluster/${CLUSTER_NAME}
rm -rf /opt/kud/multi-cluster/addons
make delete
