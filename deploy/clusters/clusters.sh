#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

FLANNEL_VERSION="v0.15.0"

# This may be used to update the in-place addon YAML files from the
# upstream projects
function build_source {
    mkdir -p ${SCRIPTDIR}/addons

    # Flannel
    curl -sL https://raw.githubusercontent.com/coreos/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml -o ${SCRIPTDIR}/addons/flannel.yaml
    cat <<EOF >${SCRIPTDIR}/templates/flannel-addon.yaml
{{- range \$clusterName, \$cluster := .Values.clusters }}
{{- if eq \$cluster.cni "flannel" }}
---
$(kubectl create configmap flannel-addon --from-file=${SCRIPTDIR}/addons/flannel.yaml -o yaml --dry-run=client)
{{- end }}
{{- end }}
EOF
    sed -i -e 's/  name: flannel-addon/  name: {{ $clusterName }}-flannel-addon/' ${SCRIPTDIR}/templates/flannel-addon.yaml
    sed -i -e 's/10.244.0.0\/16/{{ $cluster.podCidr }}/' ${SCRIPTDIR}/templates/flannel-addon.yaml

    # Flux
    flux install --export >${SCRIPTDIR}/addons/flux-system.yaml
    # The name "sync" must be sorted after "flux-system" to ensure
    # Flux CRDs are instantiated first
    cat <<'EOF' >${SCRIPTDIR}/addons/sync.yaml
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: {{ $cluster.flux.repositoryName }}
  namespace: flux-system
spec:
  gitImplementation: go-git
  interval: 1m0s
  ref:
    branch: {{ $cluster.flux.branch }}
  timeout: 20s
  url: {{ $cluster.flux.url }}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: {{ $clusterName }}-flux-sync
  namespace: flux-system
spec:
  interval: 10m0s
  path: {{ $cluster.flux.path }}
  prune: true
  sourceRef:
    kind: GitRepository
    name: {{ $cluster.flux.repositoryName }}
EOF
    cat <<EOF >${SCRIPTDIR}/templates/flux-addon.yaml
{{- range \$clusterName, \$cluster := .Values.clusters }}
{{- if \$cluster.flux }}
---
$(kubectl create configmap flux-addon --from-file=${SCRIPTDIR}/addons/flux-system.yaml,${SCRIPTDIR}/addons/sync.yaml -o yaml --dry-run=client)
{{- end }}
{{- end }}
EOF
    sed -i -e 's/  name: flux-addon/  name: {{ $clusterName }}-flux-addon/' ${SCRIPTDIR}/templates/flux-addon.yaml
}

case $1 in
    "build-source") build_source ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree addon YAML files
EOF
       ;;
esac
