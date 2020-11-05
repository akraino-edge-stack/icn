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

if [[ $status == "Completed" ]];
then
   printf "KUD Install Job completed\n"
   printf "Checking cluster status\n"

   source ../../env/lib/common.sh
   KUBECONFIG=--kubeconfig=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/admin.conf
   APISERVER=$(kubectl ${KUBECONFIG} config view --minify -o jsonpath='{.clusters[0].cluster.server}')
   TOKEN=$(kubectl ${KUBECONFIG} get secret $(kubectl ${KUBECONFIG} get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode )
   if ! call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure;
   then
     printf "\nKubernetes Cluster Install did not complete successfully\n"
   else
     printf "\nKubernetes Cluster Install was successful\n"
   fi

else
   printf "KUD Install Job failed\n"
fi


#Print logs of Job Pod
jobPod=$(kubectl get pods|grep kud-${CLUSTER_NAME})
podName=$(echo $jobPod | cut -d " " -f 1)
printf "\nNow Printing Job pod logs\n"
kubectl logs $podName

#Tear down setup
printf "\n\nBeginning BMH E2E Test Teardown\n\n"
kubectl delete -f e2etest/test_bmh_provisioning_cr.yaml
kubectl delete job kud-${CLUSTER_NAME}
kubectl delete configmap ${CLUSTER_NAME}-configmap
rm -rf /opt/kud/multi-cluster/${CLUSTER_NAME}
make delete
