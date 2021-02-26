#!/usr/bin/env bash
set -eu -o pipefail

CLUSTER_NAME=cluster-test
NUM_MASTERS=${NUM_MASTERS:-"1"}
NUM_WORKERS=${NUM_WORKERS:-"1"}

# Create Fake DHCP File
mkdir -p /opt/icn/dhcp
cat <<EOF > /opt/icn/dhcp/dhcpd.leases
# The format of this file is documented in the dhcpd.leases(5) manual page.
# This lease file was written by isc-dhcp-4.3.5

# authoring-byte-order entry is generated, DO NOT DELETE
authoring-byte-order little-endian;

EOF
for ((master=0;master<NUM_MASTERS;++master)); do
    lease=$(virsh net-dhcp-leases baremetal |grep "master-${master}")
    mac=$(echo $lease | cut -d " " -f 3)
    ip=$(echo $lease | cut -d " " -f 5)
    ip="${ip%%/*}"
    cat <<EOF >> /opt/icn/dhcp/dhcpd.leases
lease ${ip} {
  starts 4 2019/08/08 22:32:49;
  ends 4 2019/08/08 23:52:49;
  cltt 4 2019/08/08 22:32:49;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet ${mac};
  client-hostname "master-${master}";
}
EOF
done
for ((worker=0;worker<NUM_WORKERS;++worker)); do
    lease=$(virsh net-dhcp-leases baremetal |grep "worker-${worker}")
    mac=$(echo $lease | cut -d " " -f 3)
    ip=$(echo $lease | cut -d " " -f 5)
    ip="${ip%%/*}"
    cat <<EOF >> /opt/icn/dhcp/dhcpd.leases
lease ${ip} {
  starts 4 2019/08/08 22:32:49;
  ends 4 2019/08/08 23:52:49;
  cltt 4 2019/08/08 22:32:49;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet ${mac};
  client-hostname "worker-${worker}";
}
EOF
done

# Create provisioning CR file for testing
cat <<EOF > e2etest/e2e_test_provisioning_cr.yaml
apiVersion: bpa.akraino.org/v1alpha1
kind: Provisioning
metadata:
  name: e2e-test-provisioning
  labels:
    cluster: ${CLUSTER_NAME}
    owner: c1
spec:
  masters:
EOF
for ((master=0;master<NUM_MASTERS;++master)); do
    lease=$(virsh net-dhcp-leases baremetal |grep "master-${master}")
    mac=$(echo $lease | cut -d " " -f 3)
    cat <<EOF >> e2etest/e2e_test_provisioning_cr.yaml
    - master-${master}:
        mac-address: ${mac}
EOF
done
cat <<EOF >> e2etest/e2e_test_provisioning_cr.yaml
  workers:
EOF
for ((worker=0;worker<NUM_WORKERS;++worker)); do
    lease=$(virsh net-dhcp-leases baremetal |grep "worker-${worker}")
    mac=$(echo $lease | cut -d " " -f 3)
    cat <<EOF >> e2etest/e2e_test_provisioning_cr.yaml
    - worker-${worker}:
        mac-address: ${mac}
EOF
done
cat <<EOF >> e2etest/e2e_test_provisioning_cr.yaml
  KUDPlugins:
    - emco
EOF
kubectl apply -f e2etest/e2e_test_provisioning_cr.yaml
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

#Teardown Setup
printf "\n\nBeginning E2E Test Teardown\n\n"
kubectl delete -f e2etest/e2e_test_provisioning_cr.yaml
kubectl delete job kud-${CLUSTER_NAME}
kubectl delete --ignore-not-found=true configmap ${CLUSTER_NAME}-configmap
rm e2etest/e2e_test_provisioning_cr.yaml
rm -rf /opt/kud/multi-cluster/${CLUSTER_NAME}
rm /opt/icn/dhcp/dhcpd.leases
make delete
