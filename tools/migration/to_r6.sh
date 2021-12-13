#!/bin/bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="${SCRIPTDIR}/../../env/lib"

source ${LIBDIR}/common.sh

function usage {
    cat <<EOF
Usage: $(basename $0) -n nodes.json -p provisioning.yaml >site.yaml

This tool assists in migrating ICN R5 and earlier configurations to R6
by translating an existing nodes.json and Provisioning resource YAML
into values files to provide to the ICN machine and cluster Helm
charts.

IMPORTANT: The tool is only intended to be a starting point.  The
following limitations should be noted:
- The Kubernetes control plane endpoint must be explicitly specified
  with the controlPlaneEndpoint and controlPlanePrefix values in the
  cluster values YAML.
- The value of image_name in nodes.json is ignored.
- The SSH authorized key that will copied to the provisioned nodes is
  ${HOME}/.ssh/id_rsa.pub.
- spec.KUDPlugins in the Provisioning resource is ignored.  This
  functionality is accomplished in R6 with Flux.

After reviewing and updating the migrated site YAML as needed, the
YAML secrets may be encrypted with the below command before committing
to source control for use with Flux:

  $(readlink -f ${SCRIPTDIR}/../../deploy/site/site.sh) sops-encrypt-site site.yaml key-name

EOF
    exit 1
}

function migrate {
    cat <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: metal3
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: icn
  namespace: metal3
spec:
  gitImplementation: go-git
  interval: 1m0s
  ref:
    branch: master
  timeout: 20s
  url: https://gerrit.akraino.org/r/icn
EOF
    list_nodes | while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
	cat <<EOF
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: ${name}
  namespace: metal3
spec:
  interval: 5m
  chart:
    spec:
      chart: deploy/machine
      sourceRef:
        kind: GitRepository
        name: icn
      interval: 1m
  values:
EOF
	node_machine_values | sed -e 's/^/    /'
    done
    cat <<EOF
---
apiVersion: helm.toolkit.fluxcd.io/v2beta1
kind: HelmRelease
metadata:
  name: $(provisioning_json | jq -r '.metadata.name')
  namespace: metal3
spec:
  interval: 5m
  chart:
    spec:
      chart: deploy/cluster
      sourceRef:
        kind: GitRepository
        name: icn
      interval: 1m
    values:
EOF
    cluster_values | sed -e 's/^/    /'
}

function cluster_values {
    cat <<EOF
clusterName: $(cluster_name)
clusterLabels:
  owner: $(provisioning_json | jq -r '.metadata.labels.owner')
  provider: $(provisioning_json | jq -r '.metadata.labels.owner')
EOF
    if [[ $(cluster_type) != "null" ]]; then
	cat <<EOF
  cluster-type: $(cluster_type)
EOF
    fi
    cat <<EOF
numControlPlaneMachines: $(provisioning_json | jq -r '.spec.masters | length')
numWorkerMachines: $(provisioning_json | jq -r '.spec.workers | length')
controlPlaneEndpoint: # TODO
controlPlanePrefix: # TODO
controlPlaneHostSelector:
  matchExpressions:
    key: machine
    operator: In
    values:
$(provisioning_json | jq -r '.spec.masters[] | keys[0]' | awk '{print "    - " $0}')
workersHostSelector:
  matchExpressions:
    key: machine
    operator: In
    values:
$(provisioning_json | jq -r '.spec.workers[] | keys[0]' | awk '{print "    - " $0}')
userData: {}
# TODO
#flux:
#  url: https://gerrit.akraino.org/r/icn
#  branch: master
#  path: ./deploy/site/cluster-e2etest
EOF
}

function cluster_name {
    provisioning_json | jq -r '.metadata.labels.cluster'
}

function cluster_type {
    provisioning_json | jq -r '.metadata.labels."cluster-type"'
}

function provisioning_json {
    cat ${PROVISIONING_YAML} | python3 -c 'import sys, yaml, json; print(json.dumps(yaml.safe_load(sys.stdin.read())))'
}

while getopts ":n:o:p:" opt; do
    case "${opt}" in
        n)
            NODES_JSON=${OPTARG}
            ;;
        p)
            PROVISIONING_YAML=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [[ -z "${NODES_JSON}" ]] || [[ -z "${PROVISIONING_YAML}" ]]; then
    usage
fi

export NODES_FILE=${NODES_JSON}
migrate
