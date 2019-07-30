## Intel Rook infrastructure for Ceph cluster deployment

By default create osd on folder /var/lib/rook/storage-dir with 10GB for database and
journal.
So the requirement for Ceph storage of each node is 20GB+ free disk space.

To bring up Rook operator(v1.0) and Ceph cluster(Mimic 13.2.2) as following:

```console
cd yaml
./install.sh
```

If you want to make a test on the ceph workload, you check as following:

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

