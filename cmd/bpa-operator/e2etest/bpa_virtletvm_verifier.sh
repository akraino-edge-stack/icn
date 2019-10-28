#!/bin/bash

printf "\n\nStart Virtlet VM provisioning E2E test\n\n"

TUNING_DIR="/tmp/tuning_dir"
CNI_PLUGINS="cni-plugins-linux-amd64-v0.8.2.tgz"
if !(wget https://github.com/containernetworking/plugins/releases/download/v0.8.2/$CNI_PLUGINS -P $TUNING_DIR 2>/dev/null); then
    echo "Error downloading cni plugins for Virtlet VM provisioning"
    exit 1
fi

pushd $TUNING_DIR
if [ -f $CNI_PLUGINS ]; then
    tar -xzvf $CNI_PLUGINS > /dev/null
    if [ -f "tuning" ]; then
	cp "tuning" "/opt/cni/bin/"
	echo "Updated the tuning plugin"
    else
	echo "Error finding the latest tuning plugin"
	rm -rf $TUNING_DIR
	exit 1
    fi
    rm -rf $TUNING_DIR
fi
popd

# create flannel-vm net-attach-def
kubectl apply -f ../deploy/netattachdef-flannel-vm.yaml -n kube-system

# generate user ssh key
if [ ! -f "/root/.ssh/id_rsa.pub" ]; then
    ssh-keygen -f /root/.ssh/id_rsa -P ""
fi

# create virtlet vm
key=$(cat /root/.ssh/id_rsa.pub)
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

printf "\nkubectl get pods $(kubectl get pods |grep -i virtlet-deployment | awk '{print $1}') -o json\n"
podjson=$(kubectl get pods $(kubectl get pods |grep -i virtlet-deployment | awk '{print $1}') -o json)
printf "\n$podjson\n\n"

# create provisioning cr
kubectl apply -f e2e_virtletvm_test_provisioning_cr.yaml

sleep 2m

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

printf "\nPrinting kud-cluster-vm job logs....\n\n"
kudjob=$(kubectl get pods | grep -i kud-cluster-vm | awk '{print $1}')
printf "$(kubectl logs $kudjob)\n"

printf "\n\nBeginning E2E VM Test Teardown\n\n"

kubectl delete -f e2e_virtletvm_test_provisioning_cr.yaml
kubectl delete job kud-cluster-vm
kubectl delete configmap cluster-vm-configmap
kubectl delete -f virtlet_test_vm.yaml
