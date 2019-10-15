#!/bin/bash

cp fake_dhcp_lease /opt/icn/dhcp/dhcpd.leases
kubectl apply -f bmh-bpa-test.yaml
cat /root/.ssh/id_rsa.pub > vm_authorized_keys
vagrant up
sleep 5
kubectl apply -f e2e_test_provisioning_cr.yaml
sleep 2
status="Running"

while [[ $status == "Running" ]]
do
	stats=$(kubectl get pods |grep -i kud-cluster-test)

	status=$(echo $stats | cut -d " " -f 3)
	echo "KUD install job still running"
	sleep 2m
done

if [[ $status == "Completed" ]];
then
   printf "KUD Install completed successfully\n"
else
   printf "KUD Install failed\n"
fi

printf "\n\nBeginning E2E Test Teardown\n\n"

kubectl delete -f e2e_test_provisioning_cr.yaml
kubectl delete -f bmh-bpa-test.yaml
kubectl delete job kud-cluster-test
vagrant destroy -f	
