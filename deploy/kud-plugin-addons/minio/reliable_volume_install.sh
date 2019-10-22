#!/bin/bash

# Make sure 64GB+ free space.

. ../rook/yaml/install.sh

ceph_mon_ls="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph mon stat")"
ceph_mon_ls="$(echo $ceph_mon_ls | cut -d "{" -f2 | cut -d "}" -f1)"
echo $ceph_mon_ls
sed -i "s?monitors:.*?monitors: $ceph_mon_ls?" rbd/storageclass.yaml

kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph -c /var/lib/rook/rook-ceph/rook-ceph.config auth get-or-create-key client.kube mon \"allow profile rbd\" osd \"profile rbd pool=rbd\""

admin_secret="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph auth get-key client.admin|base64")"
kube_secret="$(kubectl exec -ti -n rook-ceph $(kubectl -n rook-ceph get pod -l "app=rook-ceph-operator" -o jsonpath='{.items[0].metadata.name}') -- bash -c "ceph auth get-key client.kube|base64")"

admin_secret="$(echo $admin_secret | tr -d '^M')"
kube_secret="$(echo $kube_secret | tr -d '^M')"

sed -i "s?admin:.*?admin: \"$admin_secret\"?" rbd/secret.yaml
sed -i "s?kube:.*?kube: \"$kube_secret\"?" rbd/secret.yaml


kubectl create -f ./rbd/storageclass.yaml
kubectl create -f ./rbd/secret.yaml
kubectl create -f ./rbd/pvc.yaml

# Create deployment of MinIO server
kubectl create -f minio-deployment.yaml

# Create service for MinIO
kubectl create -f minio-service.yaml

