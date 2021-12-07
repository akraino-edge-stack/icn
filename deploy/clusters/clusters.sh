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

    # PodSecurityPolicy is being replaced in future versions of K8s.
    # The recommended practice is described by K8s at
    # - https://kubernetes.io/docs/concepts/policy/pod-security-policy/#recommended-practice
    # - https://kubernetes.io/docs/concepts/security/pod-security-standards/
    # and provides three levels: privileged, baseline, and restricted.
    #
    # The question to answer here is how to reconcile the K8s levels
    # against the Akraino security requirements.
    #
    # For the time being, the below populates the cluster with the K8s
    # recommended levels and provides an additional policy (icn) bound
    # to the system:authenticated group to meet the Akraino
    # requirements.
    cat <<EOF >${SCRIPTDIR}/addons/podsecurity.yaml
---
$(curl -sL https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/privileged-psp.yaml)
---
$(curl -sL https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/baseline-psp.yaml)
---
$(curl -sL https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/restricted-psp.yaml)
---
$(curl -sL https://raw.githubusercontent.com/kubernetes/website/main/content/en/examples/policy/privileged-psp.yaml |
  sed -e 's/  name: privileged/  name: icn/' |
  sed -e '/^  allowedCapabilities:/,/^  [!-]/d')
  allowedCapabilities:
    - 'NET_ADMIN'
    - 'SYS_ADMIN'
    - 'SYS_NICE'
    - 'SYS_PTRACE'
  requiredDropCapabilities:
    - 'NET_RAW'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:privileged
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - policy
  resourceNames:
  - privileged
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:baseline
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - policy
  resourceNames:
  - baseline
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:icn
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - policy
  resourceNames:
  - icn
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: psp:restricted
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
rules:
- apiGroups:
  - policy
  resourceNames:
  - restricted
  resources:
  - podsecuritypolicies
  verbs:
  - use
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:privileged:nodes
  namespace: kube-system
  labels:
    addonmanager.kubernetes.io/mode: Reconcile
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:privileged
subjects:
- kind: Group
  name: system:nodes
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:privileged:kube-system
  namespace: kube-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:privileged
subjects:
- kind: Group
  name: system:serviceaccounts:kube-system
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: psp:icn:any
roleRef:
  kind: ClusterRole
  name: psp:icn
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  name: system:authenticated
  apiGroup: rbac.authorization.k8s.io
EOF
    cat <<EOF >${SCRIPTDIR}/templates/podsecurity-addon.yaml
{{- range \$clusterName, \$cluster := .Values.clusters }}
---
$(kubectl create configmap podsecurity-addon --from-file=${SCRIPTDIR}/addons/podsecurity.yaml -o yaml --dry-run=client)
{{- end }}
EOF
    sed -i -e 's/  name: podsecurity-addon/  name: {{ $clusterName }}-podsecurity-addon/' ${SCRIPTDIR}/templates/podsecurity-addon.yaml

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
