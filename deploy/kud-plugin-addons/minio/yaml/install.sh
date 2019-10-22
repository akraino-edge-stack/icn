#!/bin/bash

ICN_DIR=$(dirname "$(dirname "$(dirname "$(dirname "$PWD")")")")

# Make sure 64GB+ free space.

echo "s"|sudo -S mkdir /mnt/minio

echo "ICN_DIR: $ICN_DIR"
# Create local-sc persistent volume first since not support dynamic provisioning.
kubectl apply -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-pv.yaml

# Create storage class for local-sc
kubectl apply -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-sc.yaml

# Create persistent volume claim for minio server
kubectl apply -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-pvc.yaml

# Create deployment of MinIO server
kubectl apply -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/minio-deployment.yaml

# Create service for MinIO
kubectl apply -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/minio-service.yaml

