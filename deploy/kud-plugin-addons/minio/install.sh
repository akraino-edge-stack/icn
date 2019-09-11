#!/bin/bash

# Make sure 64GB+ free space.

echo ""|sudo -S mkdir /mnt/disks
echo ""|sudo -S mkdir /mnt/disks/vol1

# Create local-storage persistent volume first since not support dynamic provisioning.
kubectl create -f local-pv.yaml

# Create storage class for local-storage
kubectl create -f local-sc.yaml

# Create persistent volume claim for minio server
kubectl create -f local-pvc.yaml

# Create deployment of MinIO server
kubectl create -f minio-deployment.yaml

# Create service for MinIO
kubectl create -f minio-service.yaml

