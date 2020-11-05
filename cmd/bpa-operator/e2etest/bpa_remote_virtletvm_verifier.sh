#!/usr/bin/env bash
set -eu -o pipefail

printf "\n\nStart Remote Virtlet VM provisioning E2E test\n\n"

# remote compute provisioned and kube config available
source ~/ICN/latest/icn/env/lib/common.sh
CLUSTER_NAME=bpa-remote
KUBECONFIG=--kubeconfig=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/admin.conf
APISERVER=$(kubectl ${KUBECONFIG} config view --minify -o jsonpath='{.clusters[0].cluster.server}')
TOKEN=$(kubectl ${KUBECONFIG} get secret $(kubectl ${KUBECONFIG} get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode )
if ! call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure;
then
  printf "\nRemote Kubernetes Cluster Install did not complete successfully\n"
else
  printf "\niRemote Kubernetes Cluster Install was successful\n"
fi

# create virtlet VM in remote compute
printf "Create remote Virtlet VM ...\n"
key=$(cat /opt/kud/multi-cluster/.ssh/id_rsa.pub)
cp ../deploy/virtlet-deployment-sample.yaml bpa_remote_virtletvm.yaml
sed -i "s|\$ssh_key|${key}|" bpa_remote_virtletvm.yaml
kubectl ${KUBECONFIG} create -f bpa_remote_virtletvm.yaml

status=""
while [[ $status != "Running" ]]
do
        stats=$(kubectl ${KUBECONFIG} get pods |grep -i virtlet-deployment)
        status=$(echo $stats | cut -d " " -f 3)
        if [[ $status == "Err"* ]]; then
                echo "Error creating remote Virtlet VM, test incomplete"
                kubectl ${KUBECONFIG} delete -f bpa_remote_virtletvm.yaml
                exit 1
        fi
done

echo "Remote Virtlet VM is ready for provisioning"

printf "\nkubectl ${KUBECONFIG} get pods $(kubectl ${KUBECONFIG} get pods |grep -i virtlet-deployment | awk '{print $1}') -o json\n"
podjson=$(kubectl ${KUBECONFIG} get pods $(kubectl ${KUBECONFIG} get pods |grep -i virtlet-deployment | awk '{print $1}') -o json)
printf "\n$podjson\n\n"

printf "Provision remote Virtlet VM ...\n"
kubectl  ${KUBECONFIG} apply -f bpa_remote_virtletvm_cr.yaml

#Check Status of remote kud job pod
status="Running"

while [[ $status == "Running" ]]
do
        echo "KUD install job still running"
        sleep 2m
        stats=$(kubectl ${KUBECONFIG} get pods |grep -i kud-)
        status=$(echo $stats | cut -d " " -f 3)
done

if [[ $status == "Completed" ]];
then
   printf "KUD Install Job completed\n"
   printf "Checking cluster status\n"
else
   printf "KUD Install Job failed\n"
fi

#Print logs of Job Pod
jobPod=$(kubectl ${KUBECONFIG} get pods|grep kud-)
podName=$(echo $jobPod | cut -d " " -f 1)
printf "\nNow Printing Job pod logs\n"
kubectl ${KUBECONFIG} logs $podName

#printf "\n\nBeginning E2E Remote VM Test Teardown\n\n"

kubectl ${KUBECONFIG} delete -f bpa_remote_virtletvm_cr.yaml
kubectl ${KUBECONFIG} delete job kud-remotevvm
kubectl ${KUBECONFIG} delete configmap remotevvm-configmap
kubectl  ${KUBECONFIG} delete -f bpa_remote_virtletvm.yaml
