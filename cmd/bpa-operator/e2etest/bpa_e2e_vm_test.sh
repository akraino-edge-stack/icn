#!/bin/bash

printf "\n\nStart Virtlet VM provisioning E2E test\n\n"

# create flannel-vm net-attach-def
kubectl apply -f ../deploy/netattachdef-flannel-vm.yaml

# create virtlet vm
key=$(cat $HOME/.ssh/id_rsa.pub)
cp ../deploy/virtlet-deployment-sample.yaml virtlet_test_vm.yaml
sed -i "s|\$ssh_key|${key}|" virtlet_test_vm.yaml
kubectl create -f virtlet_test_vm.yaml

status=""
while [[ $status != "Running" ]]
do
        stats=$(kubectl get pods |grep -i virtlet-deployment)
        status=$(echo $stats | cut -d " " -f 3)

        if [[ $status == "Err"* ]]; then
            echo "Error creating Virtlet VM, test incomplete"
            kubectl delete -f virtlet_test_vm.yaml
            exit 1
        fi
done

sleep 3
echo "Virtlet VM is ready for provisioning"

# create provisioning cr
kubectl apply -f provisioning_cr_test_vm.yaml

status="Running"

while [[ $status == "Running" ]]
do
        stats=$(kubectl get pods |grep -i kud-cluster-vm)
        status=$(echo $stats | cut -d " " -f 3)
        echo "KUD install job still running"
        sleep 2m
done

if [[ $status == "Completed" ]]; then
   printf "KUD Install completed successfully\n"
else
   printf "KUD Install failed\n"
fi

printf "\n\nBeginning E2E VM Test Teardown\n\n"

kubectl delete -f provisioning_cr_test_vm.yaml
kubectl delete job kud-cluster-vm
kubectl delete -f virtlet_test_vm.yaml
