#!/usr/bin/env bash
set -eu -o pipefail

ICN_DIR=$(dirname "$(dirname "$PWD")")

kubectl delete -f service.yml

pushd $ICN_DIR/deploy/kud-plugin-addons/minio/yaml

./uninstall.sh

popd

kubectl delete -f bpa_api_cluster_role_binding.yml

kubectl delete -f bpa_api_cluster_role.yml

kubectl delete -f create-service-account.yml

sleep 10

sudo docker rmi akraino.org/icn/bpa-restapi-agent:latest

sudo docker rmi mongo:latest

sudo docker rmi minio/minio:latest
