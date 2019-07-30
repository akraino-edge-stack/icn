#!/bin/bash

# Make sure kubernetes server is up with network dns
# kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/62e44c867a2846fefb68bd5f178daf4da3095ccb/Documentation/kube-flannel.yml

# Remove taint if have
# kubectl taint nodes master node-role.kubernetes.io/master:NoSchedule-

# Remove remaining config files of last deplpyment
echo ""|sudo -S rm -rf /var/lib/rook/*

# Create common CRD objects
kubectl create -f rook-common.yaml

# Create rbac, since rook operator is not permitted to create rbac rules, these
# rules have to be created outside of operator
kubectl apply -f ./csi/rbac/rbd/
kubectl apply -f ./csi/rbac/cephfs/

# Start rook ceph operator with csi support
kubectl create -f rook-operator-with-csi.yaml

# Bring up cluster with default configuration, current Ceph version is:
# ceph/ceph:v14.2.1-20190430, and create osd with default /dev/sdb on each node
kubectl create -f rook-ceph-cluster.yaml

# Start toolbox containers with CLI support, to enter the bash env, use command:
# kubectl -n rook-ceph exec -it $(kubectl -n rook-ceph get pod -l "app=rook-ceph-tools" -o jsonpath='{.items[0].metadata.name}') bash
kubectl create -f rook-toolbox.yaml

