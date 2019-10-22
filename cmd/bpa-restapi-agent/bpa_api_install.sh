#!/bin/bash

ICN_DIR=$(dirname "$(dirname "$PWD")")

kubectl apply -f create-service-account.yml

kubectl apply -f bpa_api_cluster_role.yml

kubectl apply -f bpa_api_cluster_role_binding.yml

pushd $ICN_DIR/deploy/kud-plugin-addons/minio/yaml

./install.sh

popd

kubectl apply -f service.yml
