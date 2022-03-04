#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

# The upstream repo is not in an easily consumed structure, so first
# grab all the YAMLs then build out what we need in the overlay
function build_source {
    mkdir -p ${SCRIPTDIR}/base
    for yaml in cmk-namespace.yaml cmk-rbac-rules.yaml cmk-serviceaccount.yaml; do
	curl -sL https://raw.githubusercontent.com/intel/CPU-Manager-for-Kubernetes/${CPU_MANAGER_VERSION}/resources/authorization/${yaml} -o ${SCRIPTDIR}/base/${yaml}
    done
    for yaml in cmk-init-pod.yaml cmk-discover-pod.yaml cmk-install-pod.yaml cmk-nodereport-daemonset.yaml cmk-reconcile-daemonset.yaml; do
	curl -sL https://raw.githubusercontent.com/intel/CPU-Manager-for-Kubernetes/${CPU_MANAGER_VERSION}/resources/pods/${yaml} -o ${SCRIPTDIR}/base/${yaml}
    done
    for yaml in cmk-webhook-certs.yaml cmk-webhook-configmap.yaml cmk-webhook-service.yaml cmk-webhook-deployment.yaml cmk-webhook-config.yaml; do
	curl -sL https://raw.githubusercontent.com/intel/CPU-Manager-for-Kubernetes/${CPU_MANAGER_VERSION}/resources/webhook/${yaml} -o ${SCRIPTDIR}/base/${yaml}
    done
    rm -f ${SCRIPTDIR}/base/kustomization.yaml
    pushd ${SCRIPTDIR}/base && kustomize create --autodetect && popd

    mkdir -p ${SCRIPTDIR}/icn
    cat <<EOF >${SCRIPTDIR}/icn/daemonset-init-containers-patch.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: cmk-reconcile-ds-all
  namespace: cmk-namespace
spec:
  template:
    spec:
      containers:
$(yq eval '.spec.template.spec.containers' ${SCRIPTDIR}/base/cmk-nodereport-daemonset.yaml | awk '{print "      "$0}')
      initContainers:
$(yq eval '.spec.containers' ${SCRIPTDIR}/base/cmk-init-pod.yaml | awk '{print "      "$0}')
$(yq eval '.spec.containers' ${SCRIPTDIR}/base/cmk-discover-pod.yaml | awk '{print "      "$0}')
$(yq eval '.spec.containers' ${SCRIPTDIR}/base/cmk-install-pod.yaml | awk '{print "      "$0}')
EOF
    yq '(.spec.template.spec.initContainers[0].env[] | select(.name=="NUM_EXCLUSIVE_CORES").value) = 2' -i ${SCRIPTDIR}/icn/daemonset-init-containers-patch.yaml
    yq '(.spec.template.spec.initContainers[1].args[0] = "/cmk/cmk.py discover --conf-dir=/etc/cmk --no-taint"' -i ${SCRIPTDIR}/icn/daemonset-init-containers-patch.yaml
    yq '.spec.template.spec += {"volumes":[{"hostPath":{"path":"/opt/bin"},"name":"cmk-install-dir"}]}' -i ${SCRIPTDIR}/icn/daemonset-init-containers-patch.yaml
}

case $1 in
    "build-source") build_source ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree YAML files
EOF
       ;;
esac
