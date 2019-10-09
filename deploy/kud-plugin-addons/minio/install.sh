#!/bin/bash

ICN_DIR=$(dirname "$(dirname "$(dirname "$PWD")")")

# Make sure 64GB+ free space.

echo "s"|sudo -S mkdir /mnt/minio

# Create local-storage persistent volume first since not support dynamic provisioning.
kubectl create -f $ICN_DIR/deploy/kud-plugin-addons/minio/local-pv.yaml

# Create storage class for local-storage
kubectl create -f $ICN_DIR/deploy/kud-plugin-addons/minio/local-sc.yaml

# Create persistent volume claim for minio server
kubectl create -f $ICN_DIR/deploy/kud-plugin-addons/minio/local-pvc.yaml

# Create deployment of MinIO server
kubectl create -f $ICN_DIR/deploy/kud-plugin-addons/minio/minio-deployment.yaml

# Create service for MinIO
# kubectl create -f minio-service.yaml

