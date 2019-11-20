#!/bin/bash

# Get MAC and IP addresses of VMs provisioned by metal3
master0=$(virsh net-dhcp-leases baremetal |grep master-0)
masterMAC=$(echo $master0 | cut -d " " -f 3)
masterIP=$(echo $master0 | cut -d " " -f 5)
masterIP="${masterIP%%/*}"

worker0=$(virsh net-dhcp-leases baremetal |grep worker-0)
workerMAC=$(echo $worker0 | cut -d " " -f 3)
workerIP=$(echo $worker0 | cut -d " " -f 5)
workerIP="${workerIP%%/*}"

# Create Fake DHCP File
mkdir -p /opt/icn/dhcp
cat <<EOF > /opt/icn/dhcp/dhcpd.leases
# The format of this file is documented in the dhcpd.leases(5) manual page.
# This lease file was written by isc-dhcp-4.3.5

# authoring-byte-order entry is generated, DO NOT DELETE
authoring-byte-order little-endian;

lease ${masterIP} {
  starts 4 2019/08/08 22:32:49;
  ends 4 2019/08/08 23:52:49;
  cltt 4 2019/08/08 22:32:49;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet ${masterMAC};
  client-hostname "master-0";
}
lease ${workerIP} {
  starts 4 2019/08/08 22:32:49;
  ends 4 2019/08/08 23:52:49;
  cltt 4 2019/08/08 22:32:49;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet ${workerMAC};
  client-hostname "worker-0";
}
EOF

# Create provisioning CR file for testing
cat <<EOF > e2etest/e2e_test_provisioning_cr.yaml
apiVersion: bpa.akraino.org/v1alpha1
kind: Provisioning
metadata:
  name: e2e-test-provisioning
  labels:
    cluster: cluster-test
    owner: c1
spec:
  masters:
    - master-0:
        mac-address: ${masterMAC}
  workers:
    - worker-0:
        mac-address: ${workerMAC}
EOF
kubectl apply -f e2etest/e2e_test_provisioning_cr.yaml
sleep 5

#Check Status of kud job pod
status="Running"

while [[ $status == "Running" ]]
do
	echo "KUD install job still running"
	sleep 2m
	stats=$(kubectl get pods |grep -i kud-cluster-test)
	status=$(echo $stats | cut -d " " -f 3)
done

if [[ $status == "Completed" ]];
then
   printf "KUD Install Job completed\n"
   printf "Checking cluster status\n"

   source ../../env/lib/common.sh
   CLUSTER_NAME=cluster-test
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


#Print logs of Job Pod
jobPod=$(kubectl get pods|grep kud-cluster-test)
podName=$(echo $jobPod | cut -d " " -f 1)
printf "\nNow Printing Job pod logs\n"
kubectl logs $podName

#Teardown Setup
printf "\n\nBeginning E2E Test Teardown\n\n"
kubectl delete -f e2etest/e2e_test_provisioning_cr.yaml
kubectl delete job kud-cluster-test
kubectl delete configmap cluster-test-configmap
rm e2etest/e2e_test_provisioning_cr.yaml
rm -rf /opt/kud/multi-cluster/cluster-test
rm /opt/icn/dhcp/dhcpd.leases
make delete
