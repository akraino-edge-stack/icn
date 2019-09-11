#!/bin/bash

# Create a Persistent Volume in local mount /var/lib/minio
kubectl create -f minio-volume.yaml

# Create the PVC which used by minio server
kubectl create -f minio-pvc.yaml

# MinIO Server deployment
kubectl create -f minio-deployment.yaml

# MinIO Service, access by: http://127.0.0.1:9000
kubectl create -f minio-service.yaml
