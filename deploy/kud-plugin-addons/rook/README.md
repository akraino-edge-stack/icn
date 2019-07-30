## Intel Rook infrastructure for Ceph cluster deployment

By default create osd on folder /var/lib/rook/storage-dir, and Ceph cluster
information on /var/lib/rook.

# Precondition

1. Compute node disk space: 20GB+ free disk space.

2. Kubernetes version: Kubernetes version >= 1.13 required by Ceph CSI v1.0.
Following is the upgrade patch in kud github: https://github.com/onap/multicloud-k8s

```
$ git diff
diff --git a/kud/deployment_infra/playbooks/kud-vars.yml b/kud/deployment_infra/playbooks/kud-vars.yml
index 9b36547..5c29fa4 100644
--- a/kud/deployment_infra/playbooks/kud-vars.yml
+++ b/kud/deployment_infra/playbooks/kud-vars.yml
@@ -58,7 +58,7 @@ ovn4nfv_version: adc7b2d430c44aa4137ac7f9420e14cfce3fa354
 ovn4nfv_url: "https://git.opnfv.org/ovn4nfv-k8s-plugin/"

 go_version: '1.12.5'
-kubespray_version: 2.8.2
-helm_client_version: 2.9.1
+kubespray_version: 2.9.0
+helm_client_version: 2.13.1
 # kud playbooks not compatible with 2.8.0 - see MULTICLOUD-634
 ansible_version: 2.7.10
diff --git a/kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml b/kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml
index 9966ba8..cacb4b3 100644
--- a/kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml
+++ b/kud/hosting_providers/vagrant/inventory/group_vars/k8s-cluster.yml
@@ -48,7 +48,7 @@ local_volumes_enabled: true
 local_volume_provisioner_enabled: true

 ## Change this to use another Kubernetes version, e.g. a current beta release
-kube_version: v1.12.3
+kube_version: v1.13.5

 # Helm deployment
 helm_enabled: true
```

After upgraded, the Kubernetes version as following:
```
$ kubectl version
Client Version: version.Info{Major:"1", Minor:"13", GitVersion:"v1.13.5", GitCommit:"2166946f41b36dea2c4626f90a77706f426cdea2", GitTreeState:"clean", BuildDate:"2019-03-25T15:19:22Z", GoVersion:"go1.11.5", Compiler:"gc", Platform:"linux/amd64"}
Server Version: version.Info{Major:"1", Minor:"13", GitVersion:"v1.13.5", GitCommit:"2166946f41b36dea2c4626f90a77706f426cdea2", GitTreeState:"clean", BuildDate:"2019-03-25T15:19:22Z", GoVersion:"go1.11.5", Compiler:"gc", Platform:"linux/amd64"}
```

If something is wrong with Kubectl server version, you can manually upgrade as
command:
```console
$ kubeadm upgrade apply v1.13.5
```

# Deployment

To bring up Rook operator(v1.0) and Ceph cluster(Mimic 13.2.2) as following:

```console
cd yaml
./install.sh
```

# Test

If you want to make a test on the ceph sample workload, check as following:

1. Bring up Rook operator and Ceph cluster.
2. Goto Create storage class.

```console
kubectl create -f ./test/rbd/storageclass.yaml
```

3. Create RBD secret.
```console
kubectl exec -ti -n rook-ceph rook-ceph-operator-948f8f84c-749zb -- bash -c 
"ceph -c /var/lib/rook/rook-ceph/rook-ceph.config auth get-or-create-key client.kube mon \"allow profile rbd\" osd \"profile rbd pool=rbd\""
```
   You need to replace the pod name with your own rook-operator, refer: kubetl get pod -n rook-ceph
   Then get secret of admin and client user key by go into operator pod and execute:
```console
ceph auth get-key client.admin|base64
ceph auth get-key client.kube|base64
```
  Then fill the key into secret.yaml
```console
kubectl create -f ./test/rbd/secret.yaml
```
4. Create RBD Persistent Volume Claim
```console
kubectl create -f ./test/rbd/pvc.yaml
```
5. Create RBD demo pod
```console
kubectl creaet -f ./test/rbd/pod.yaml
```
6. Check the Volumes created and application mount status
```console
tingjie@ceph4:~/bohemian/workspace/rook/Documentation$ kubectl get pvc
NAME      STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
rbd-pvc   Bound    pvc-98f50bec-8a4f-434d-8def-7b69b628d427   1Gi        RWO            csi-rbd        84m
tingjie@ceph4:~/bohemian/workspace/rook/Documentation$ kubectl get pod
NAME              READY   STATUS    RESTARTS   AGE
csirbd-demo-pod   1/1     Running   0          84m
tingjie@ceph4:~/bohemian/workspace/rook/Documentation$ kubectl exec -ti csirbd-demo-pod -- bash
root@csirbd-demo-pod:/# df -h
Filesystem      Size  Used Avail Use% Mounted on
overlay         733G   35G  662G   5% /
tmpfs            64M     0   64M   0% /dev
tmpfs            32G     0   32G   0% /sys/fs/cgroup
/dev/sda2       733G   35G  662G   5% /etc/hosts
shm              64M     0   64M   0% /dev/shm
/dev/rbd0       976M  2.6M  958M   1% /var/lib/www/html
tmpfs            32G   12K   32G   1% /run/secrets/kubernetes.io/serviceaccount
tmpfs            32G     0   32G   0% /proc/acpi
tmpfs            32G     0   32G   0% /proc/scsi
tmpfs            32G     0   32G   0% /sys/firmware
```
7. Create RBD snapshot-class
```console
kubectl create -f ./test/rbd/snapshotclass.yaml
```
8. Create Volume snapshot and verify
```console
kubectl create -f ./test/rbd/snapshot.yaml

$ kubectl get volumesnapshotclass
NAME                      AGE
csi-rbdplugin-snapclass   51s
$ kubectl get volumesnapshot
NAME               AGE
rbd-pvc-snapshot   33s

```
9. Restore the snapshot to a new PVC and verify
```console
kubectl create -f ./test/rbd/pvc-restore.yaml

$ kubectl get pvc
NAME              STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS   AGE
rbd-pvc           Bound    pvc-98f50bec-8a4f-434d-8def-7b69b628d427   1Gi        RWO            csi-rbd        42h
rbd-pvc-restore   Bound    pvc-530a4939-e4c0-428d-a072-c9c39d110d7a   1Gi        RWO            csi-rbd        5s
```

