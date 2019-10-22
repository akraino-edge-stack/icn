#!/bin/bash

# Make sure 64GB+ free space.

#echo "...... Deploy Rook Ceph cluster ......"

kubectl create -f ./ceph-volume/rook-common.yaml
kubectl apply -f ./ceph-volume/csi/rbac/rbd/
kubectl apply -f ./ceph-volume/csi/rbac/cephfs/
kubectl create -f ./ceph-volume/rook-operator-with-csi.yaml

# Bring up cluster with default configuration, current Ceph version is:
# ceph/ceph:v14.2.1-20190430, and create osd with default /dev/sdb on each node
kubectl create -f ./ceph-volume/rook-ceph-cluster.yaml
kubectl create -f ./ceph-volume/rook-toolbox.yaml

echo "...... Deploy MinIO server ......"
echo "Waiting for 5 minutes for Ceph cluster bring up ..."
sleep 600

ceph_mon_ls="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') -- bash -c "cat /etc/ceph/ceph.conf | grep mon_host")"
ceph_mon_ls="$(echo $ceph_mon_ls | cut -d "=" -f2)"
ceph_mon_ls="$(echo ${ceph_mon_ls%?})"
echo $ceph_mon_ls
sed -i "s?monitors:.*?monitors: $ceph_mon_ls?" ceph-volume/storageclass.yaml

kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph -c /var/lib/rook/rook-ceph/rook-ceph.config auth get-or-create-key client.kube mon \"allow profile rbd\" osd \"profile rbd pool=rbd\""

admin_secret="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph auth get-key client.admin|base64")"
kube_secret="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph auth get-key client.kube|base64")"

admin_secret="$(echo ${admin_secret%?})"
kube_secret="$(echo ${kube_secret%?})"
echo $admin_secret
echo $kube_secret

sed -i "s?admin:.*?admin: \"$admin_secret\"?" ceph-volume/secret.yaml
sed -i "s?kube:.*?kube: \"$kube_secret\"?" ceph-volume/secret.yaml

kubectl create -f ./ceph-volume/storageclass.yaml
kubectl create -f ./ceph-volume/secret.yaml
kubectl create -f ./ceph-volume/pvc.yaml

# Create deployment of MinIO server
kubectl create -f minio-deployment.yaml

# Create service for MinIO
kubectl create -f minio-service.yaml

