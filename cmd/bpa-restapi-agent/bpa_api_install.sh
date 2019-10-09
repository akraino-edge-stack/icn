#!/bin/bash

kubectl apply -f create-service-account.yml

kubectl apply -f bpa_api_cluster_role.yml

kubectl apply -f bpa_api_cluster_role_binding.yml

minio_start.sh

kubectl apply -f service.yml
