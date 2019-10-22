#!/bin/bash

ICN_DIR=$(dirname "$(dirname "$(dirname "$(dirname "$PWD")")")")

# Make sure 64GB+ free space.

#echo "s"|sudo -S mkdir /mnt/minio

# Remove service for MinIO
kubectl delete -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/minio-service.yaml

# Remove deployment of MinIO server
kubectl delete -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/minio-deployment.yaml

# Remove persistent volume claim for minio server
kubectl delete -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-pvc.yaml

# Remove storage class for local-sc
kubectl delete -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-sc.yaml

# Remove local-sc persistent volume first since not support dynamic provisioning.
kubectl delete -f $ICN_DIR/deploy/kud-plugin-addons/minio/yaml/local/local-pv.yaml
