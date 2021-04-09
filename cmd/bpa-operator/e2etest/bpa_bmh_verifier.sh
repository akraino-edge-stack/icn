#!/usr/bin/env bash
set -eu -o pipefail

CLUSTER_NAME=test-bmh-cluster

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
   TOKEN=$(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl get secret $(KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode )
   if ! call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure;
   then
     printf "\nKubernetes Cluster Install did not complete successfully\n"
   else
     printf "\nKubernetes Cluster Install was successful\n"
   fi

else
   printf "KUD Install Job failed\n"
   exit 1
fi

#Install addons
printf "Installing KUD addons\n"
pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply -f prerequisites.yaml -v values.yaml
/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply -f composite-app.yaml -v values.yaml
popd

#Wait for addons to be ready
# The deployment intent group status reports instantiated before all
# Pods are ready, so wait for the instance label (.spec.version) of
# the deployment intent group instead.
status="Pending"
for try in {0..9}; do
    printf "Waiting for KUD addons to be ready\n"
    sleep 30s
    if KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl wait pod -l app.kubernetes.io/instance=r1 --for=condition=Ready --all-namespaces --timeout=0s > /dev/null; then
	status="Ready"
	break
    fi
done
[[ $status == "Ready" ]]

#Install addon resources
printf "Installing KUD addon resources\n"
pushd /opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/addons
/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh apply -f composite-app.yaml -v values-resources.yaml
popd

#Wait for addon resources to be ready
status="Pending"
for try in {0..9}; do
    printf "Waiting for KUD addon resources to be ready\n"
    sleep 30s
    if KUBECONFIG=${CLUSTER_KUBECONFIG} kubectl wait pod -l app.kubernetes.io/instance=r1 --for=condition=Ready --all-namespaces --timeout=0s > /dev/null; then
       status="Ready"
       break
    fi
done
[[ $status == "Ready" ]]

#Test addons
printf "Testing KUD addons\n"
pushd /opt/kud/multi-cluster/addons/tests
failed_kud_tests=""
for addon in multus ovn4nfv nfd sriov qat cmk; do
    KUBECONFIG=${CLUSTER_KUBECONFIG} bash ${addon}.sh || failed_kud_tests="${failed_kud_tests} ${addon}"
done
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
until [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh delete -f composite-app.yaml -v values-resources.yaml |
	    awk '/Response Code:/ {code=$3} END{print code}') =~ 404 ]]; do
    echo "Waiting for KUD addon resources to terminate"
    sleep 1s
done
until [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh delete -f composite-app.yaml -v values.yaml |
	    awk '/Response Code:/ {code=$3} END{print code}') =~ 404 ]]; do
    echo "Waiting for KUD addons to terminate"
    sleep 1s
done
until [[ $(/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/emcoctl.sh delete -f prerequisites.yaml -v values.yaml |
	    awk '/Response Code:/ {code=$3} END{print code}') =~ 404 ]]; do
    echo "Waiting for KUD addons to terminate"
    sleep 1s
done
popd
kubectl delete -f e2etest/test_bmh_provisioning_cr.yaml
kubectl delete job kud-${CLUSTER_NAME}
kubectl delete --ignore-not-found=true configmap ${CLUSTER_NAME}-configmap
rm -rf /opt/kud/multi-cluster/${CLUSTER_NAME}
make delete
