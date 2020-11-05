#!/usr/bin/env bash
set -eu -o pipefail

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

# Create network attachment definition
BPA_DIR="/tmp/bpa"
mkdir -p $BPA_DIR
cat <<EOF > $BPA_DIR/netattachdef-flannel-vm.yaml
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: flannel-vm
spec:
  config: '{
            "cniVersion": "0.3.1",
            "name" : "cni0",
            "plugins": [ {
              "type": "flannel",
              "cniVersion": "0.3.1",
              "masterplugin": true,
              "delegate": {
                  "isDefaultGateway": true
              }
            },
            {
              "type": "tuning"
            }]
          }'
EOF

cat <<'EOF' > $BPA_DIR/virtlet_test_vm.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: virtlet-deployment
  labels:
    app: virtlet
spec:
  replicas: 1
  selector:
    matchLabels:
      app: virtlet
  template:
    metadata:
      labels:
        app: virtlet
      annotations:
        VirtletLibvirtCPUSetting: |
          mode: host-passthrough
        # This tells CRI Proxy that this pod belongs to Virtlet runtime
        kubernetes.io/target-runtime: virtlet.cloud
        VirtletCloudInitUserData: |
          ssh_pwauth: True
          disable_root: false
          chpasswd: {expire: False}
          manage_resolv_conf: True
          resolv_conf:
            nameservers: ['8.8.8.8', '8.8.4.4']
          users:
          - name: root
            gecos: User
            primary-group: root
            groups: users
            lock_passwd: false
            shell: /bin/bash
            sudo: ALL=(ALL) NOPASSWD:ALL
            ssh_authorized_keys:
              $ssh_key
          runcmd:
            - sed -i -e 's/^#DNS=.*/DNS=8.8.8.8/g' /etc/systemd/resolved.conf
            - systemctl daemon-reload
            - systemctl restart systemd-resolved
        v1.multus-cni.io/default-network: '[
            { "name": "flannel-vm",
              "mac": "c2:b4:57:49:47:f1" }]'
        VirtletRootVolumeSize: 8Gi
        VirtletVCPUCount: "2"
    spec:
      affinity:
        nodeAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            nodeSelectorTerms:
            - matchExpressions:
              - key: extraRuntime
                operator: In
                values:
                - virtlet
      containers:
      - name: virtlet-deployment
        # This specifies the image to use.
        # virtlet.cloud/ prefix is used by CRI proxy, the remaining part
        # of the image name is prepended with https:// and used to download the image
        image: virtlet.cloud/ubuntu/18.04
        imagePullPolicy: IfNotPresent
        # tty and stdin required for "kubectl attach -t" to work
        tty: true
        stdin: true
        resources:
          requests:
            cpu: 2
            memory: 8Gi
          limits:
            # This memory limit is applied to the libvirt domain definition
            cpu: 2
            memory: 8Gi
EOF

# Create provisioning CR file for BPA testing
cat <<EOF > $BPA_DIR/e2e_bpa_test.yaml
apiVersion: bpa.akraino.org/v1alpha1
kind: Provisioning
metadata:
  name: vmcluster110
  labels:
    cluster: vmcluster110
    cluster-type: virtlet-vm
    owner: c1
spec:
  masters:
    - master-1:
        mac-address: c2:b4:57:49:47:f1
  PodSubnet: 172.21.64.0/18
EOF

pushd $BPA_DIR
# create flannel-vm net-attach-def
kubectl apply -f netattachdef-flannel-vm.yaml -n kube-system

# generate user ssh key
if [ ! -f "/root/.ssh/id_rsa.pub" ]; then
    ssh-keygen -f /root/.ssh/id_rsa -P ""
fi

# create ssh key secret
kubectl create secret generic ssh-key-secret --from-file=id_rsa=/root/.ssh/id_rsa --from-file=id_rsa.pub=/root/.ssh/id_rsa.pub

# create virtlet vm
key=$(cat /root/.ssh/id_rsa.pub)
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
kubectl apply -f e2e_bpa_test.yaml
popd

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

kubectl delete -f e2e_bpa_test.yaml
kubectl delete job kud-vmcluster110
kubectl delete configmap vmcluster110-configmap
kubectl delete -f virtlet_test_vm.yaml
rm -rf /opt/kud/multi-cluster/vmcluster110
rm -rf $BPA_DIR
