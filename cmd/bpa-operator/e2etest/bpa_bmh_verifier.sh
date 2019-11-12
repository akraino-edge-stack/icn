#!/bin/bash

kubectl create -f e2etest/test_bmh_provisioning_cr.yaml 
sleep 5

#Check Status of kud job pod
status="Running"

while [[ $status == "Running" ]]
do
        echo "KUD install job still running"
        sleep 2m
        stats=$(kubectl get pods |grep -i kud-test-bmh-cluster)
        status=$(echo $stats | cut -d " " -f 3)
done

if [[ $status == "Completed" ]];
then
   printf "KUD Install Job completed\n"
   printf "Checking cluster status\n"

   source ../../env/lib/common.sh
   CLUSTER_NAME=test-bmh-cluster
   KUBECONFIG=--kubeconfig=/opt/kud/multi-cluster/${CLUSTER_NAME}/artifacts/admin.conf
   APISERVER=$(kubectl ${KUBECONFIG} config view --minify -o jsonpath='{.clusters[0].cluster.server}')
   TOKEN=$(kubectl ${KUBECONFIG} get secret $(kubectl ${KUBECONFIG} get serviceaccount default -o jsonpath='{.secrets[0].name}') -o jsonpath='{.data.token}' | base64 --decode )
   call_api $APISERVER/api --header "Authorization: Bearer $TOKEN" --insecure
   ret=$?
   if [[ $ret != 0 ]];
   then
     printf "\nKubernetes Cluster Install did not complete successfully\n"
   else
     printf "\nKubernetes Cluster Install was successful\n"
   fi

else
   printf "KUD Install Job failed\n"
fi


printf "\n\nBeginning BMH E2E Test Teardown\n\n"
kubectl delete -f e2etest/test_bmh_provisioning_cr.yaml
kubectl delete job kud-test-bmh-cluster
kubectl delete configmap test-bmh-cluster-configmap
rm -rf /multi-cluster/test-bmh-cluster
make delete
