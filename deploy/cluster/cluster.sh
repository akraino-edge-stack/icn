#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/logging.sh
source $LIBDIR/common.sh

function build_source_flannel {
    curl -sL https://raw.githubusercontent.com/coreos/flannel/${FLANNEL_VERSION}/Documentation/kube-flannel.yml -o ${SCRIPTDIR}/addons/flannel.yaml
    cat <<EOF >${SCRIPTDIR}/templates/flannel-addon.yaml
{{- if eq .Values.cni "flannel" }}
---
$(kubectl create configmap flannel-addon --from-file=${SCRIPTDIR}/addons/flannel.yaml -o yaml --dry-run=client)
{{- end }}
EOF
    sed -i -e 's/  name: flannel-addon/  name: {{ .Values.clusterName }}-flannel-addon/' ${SCRIPTDIR}/templates/flannel-addon.yaml
    sed -i -e 's/10.244.0.0\/16/{{ .Values.podCidr }}/' ${SCRIPTDIR}/templates/flannel-addon.yaml
}

function build_source_flux {
    # NOTE: This reaches outside this directory to
    # deploy/site/cluster-addons/flux-system.  This is to ensure that
    # the day-0 config of a cluster using deploy/site/cluster-addons
    # is in sync with the chart.
    flux install --export >${SCRIPTDIR}/../site/cluster-addons/flux-system/gotk-components.yaml
    kustomize build ${SCRIPTDIR}/../site/cluster-addons/flux-system >${SCRIPTDIR}/addons/flux-system.yaml
    cat <<EOF >>${SCRIPTDIR}/addons/flux-system.yaml
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:privileged:flux-system
  namespace: flux-system
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:privileged
subjects:
- kind: Group
  name: system:serviceaccounts:flux-system
  apiGroup: rbac.authorization.k8s.io
EOF
    # The name "sync" must be sorted after "flux-system" to ensure
    # CRDs are instantiated first
    cat <<'EOF' >${SCRIPTDIR}/addons/sync.yaml
{{- if .Values.flux.decryptionSecret }}
---
apiVersion: v1
type: Opaque
kind: Secret
metadata:
  name: {{ .Values.flux.repositoryName }}-{{ .Values.flux.branch }}-sops-gpg
  namespace: flux-system
data:
  sops.asc: {{ .Values.flux.decryptionSecret | b64enc }}
{{- end }}
---
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: {{ .Values.flux.repositoryName }}
  namespace: flux-system
spec:
  gitImplementation: go-git
  interval: 1m0s
  ref:
    branch: {{ .Values.flux.branch }}
  timeout: 20s
  url: {{ .Values.flux.url }}
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: {{ .Values.clusterName }}-flux-sync
  namespace: flux-system
spec:
  interval: 10m0s
  path: {{ .Values.flux.path }}
  prune: true
  sourceRef:
    kind: GitRepository
    name: {{ .Values.flux.repositoryName }}
{{- if .Values.flux.decryptionSecret }}
  decryption:
    provider: sops
    secretRef:
      name: {{ .Values.flux.repositoryName }}-{{ .Values.flux.branch }}-sops-gpg
{{- end }}
EOF
    cat <<EOF >${SCRIPTDIR}/templates/flux-addon.yaml
{{- if .Values.flux }}
---
$(kubectl create configmap flux-addon --from-file=${SCRIPTDIR}/addons/flux-system.yaml,${SCRIPTDIR}/addons/sync.yaml -o yaml --dry-run=client)
{{- end }}
EOF
    sed -i -e 's/  name: flux-addon/  name: {{ .Values.clusterName }}-flux-addon/' ${SCRIPTDIR}/templates/flux-addon.yaml
}

function build_source_podsecurity {
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
---
$(kubectl create configmap podsecurity-addon --from-file=${SCRIPTDIR}/addons/podsecurity.yaml -o yaml --dry-run=client)
EOF
    sed -i -e 's/  name: podsecurity-addon/  name: {{ .Values.clusterName }}-podsecurity-addon/' ${SCRIPTDIR}/templates/podsecurity-addon.yaml
}

function build_source_calico {
    mkdir -p ${SCRIPTDIR}/addons/calico/{base,ipv4,dualstack,ipv6}
    curl -sL https://docs.projectcalico.org/archive/${CALICO_VERSION%.*}/manifests/calico.yaml -o ${SCRIPTDIR}/addons/calico/base/calico.yaml
    # Remove trailing whitespace so that kubectl create configmap
    # doesn't insert explicit newlines
    sed -i -r 's/\s+$//g' ${SCRIPTDIR}/addons/calico/base/calico.yaml
    pushd ${SCRIPTDIR}/addons/calico/base && rm -f kustomization.yaml && kustomize create --autodetect && popd

    # IPv4 only (the default)
    cat <<EOF >${SCRIPTDIR}/addons/calico/ipv4/ip-autodetection-method-patch.yaml
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: calico-node
  namespace: kube-system
spec:
  template:
    spec:
      containers:
        - name: calico-node
          env:
            - name: IP_AUTODETECTION_METHOD
              value: can-reach=www.google.com
EOF
    cat <<EOF >${SCRIPTDIR}/addons/calico/ipv4/kustomization.yaml
resources:
- ../base
patches:
- path: ip-autodetection-method-patch.yaml
EOF
    kustomize build ${SCRIPTDIR}/addons/calico/ipv4 >${SCRIPTDIR}/addons/calico/ipv4.yaml
    # Dual stack
    cat <<'EOF' >${SCRIPTDIR}/addons/calico/dualstack/configmap-patch.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: calico-config
  namespace: kube-system
data:
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "log_file_path": "/var/log/calico/cni/cni.log",
          "datastore_type": "kubernetes",
          "nodename": "__KUBERNETES_NODE_NAME__",
          "mtu": __CNI_MTU__,
          "ipam": {
              "type": "calico-ipam",
              "assign_ipv4": "true",
              "assign_ipv6": "true"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        },
        {
          "type": "bandwidth",
          "capabilities": {"bandwidth": true}
        }
      ]
    }
EOF
    cat <<EOF >${SCRIPTDIR}/addons/calico/dualstack/ip-autodetection-method-patch.yaml
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: calico-node
  namespace: kube-system
spec:
  template:
    spec:
      containers:
        - name: calico-node
          env:
            - name: IP_AUTODETECTION_METHOD
              value: can-reach=www.google.com
            - name: IP6_AUTODETECTION_METHOD
              value: can-reach=www.google.com
            - name: IP6
              value: autodetect
            - name: FELIX_IPV6SUPPORT
              value: true
EOF
    cat <<EOF >${SCRIPTDIR}/addons/calico/dualstack/kustomization.yaml
resources:
- ../base
patches:
- path: configmap-patch.yaml
- path: ip-autodetection-method-patch.yaml
EOF
    kustomize build ${SCRIPTDIR}/addons/calico/dualstack >${SCRIPTDIR}/addons/calico/dualstack.yaml
    # IPv6 only
    cat <<'EOF' >${SCRIPTDIR}/addons/calico/ipv6/configmap-patch.yaml
kind: ConfigMap
apiVersion: v1
metadata:
  name: calico-config
  namespace: kube-system
data:
  cni_network_config: |-
    {
      "name": "k8s-pod-network",
      "cniVersion": "0.3.1",
      "plugins": [
        {
          "type": "calico",
          "log_level": "info",
          "log_file_path": "/var/log/calico/cni/cni.log",
          "datastore_type": "kubernetes",
          "nodename": "__KUBERNETES_NODE_NAME__",
          "mtu": __CNI_MTU__,
          "ipam": {
              "type": "calico-ipam",
              "assign_ipv4": "false",
              "assign_ipv6": "true"
          },
          "policy": {
              "type": "k8s"
          },
          "kubernetes": {
              "kubeconfig": "__KUBECONFIG_FILEPATH__"
          }
        },
        {
          "type": "portmap",
          "snat": true,
          "capabilities": {"portMappings": true}
        },
        {
          "type": "bandwidth",
          "capabilities": {"bandwidth": true}
        }
      ]
    }
EOF
    cat <<EOF >${SCRIPTDIR}/addons/calico/ipv6/ip-autodetection-method-patch.yaml
kind: DaemonSet
apiVersion: apps/v1
metadata:
  name: calico-node
  namespace: kube-system
spec:
  template:
    spec:
      containers:
        - name: calico-node
          env:
            - name: IP6_AUTODETECTION_METHOD
              value: can-reach=www.google.com
            - name: IP6
              value: autodetect
            - name: FELIX_IPV6SUPPORT
              value: true
            - name: IP
              value: none
            - name: CALICO_ROUTER_ID
              value: hash
EOF
    cat <<EOF >${SCRIPTDIR}/addons/calico/ipv6/kustomization.yaml
resources:
- ../base
patches:
- path: configmap-patch.yaml
- path: ip-autodetection-method-patch.yaml
EOF
    kustomize build ${SCRIPTDIR}/addons/calico/ipv6 >${SCRIPTDIR}/addons/calico/ipv6.yaml

    cat <<EOF >${SCRIPTDIR}/templates/calico-addon.yaml
{{- if eq .Values.cni "calico" }}
{{- if eq .Values.ipam "ipv4" }}
---
$(kubectl create configmap calico-addon --from-file=calico.yaml=${SCRIPTDIR}/addons/calico/ipv4.yaml -o yaml --dry-run=client)
{{- end }}
{{- if eq .Values.ipam "dualstack" }}
---
$(kubectl create configmap calico-addon --from-file=calico.yaml=${SCRIPTDIR}/addons/calico/dualstack.yaml -o yaml --dry-run=client)
{{- end }}
{{- if eq .Values.ipam "ipv6" }}
---
$(kubectl create configmap calico-addon --from-file=calico.yaml=${SCRIPTDIR}/addons/calico/ipv6.yaml -o yaml --dry-run=client)
{{- end }}
{{- end }}
EOF
    sed -i -e 's/  name: calico-addon/  name: {{ .Values.clusterName }}-calico-addon/' ${SCRIPTDIR}/templates/calico-addon.yaml
}

# This may be used to update the in-place addon YAML files from the
# upstream projects
function build_source {
    mkdir -p ${SCRIPTDIR}/addons
    build_source_calico
    build_source_flannel
    build_source_flux
    build_source_podsecurity
}

case $1 in
    "build-source") build_source ;;
    "foo") build_source_calico ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source  - Rebuild the in-tree addon YAML files
EOF
       ;;
esac
