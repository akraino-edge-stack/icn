#!/usr/bin/env bash
set -eux -o pipefail

# Remove visibility of /version
kubectl --kubeconfig=/etc/kubernetes/admin.conf replace -f - <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "false"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:public-info-viewer
rules:
- nonResourceURLs:
  - /healthz
  - /livez
  - /readyz
  verbs:
  - get
EOF

# Opt out of automatic mounting of SA token
kubectl --kubeconfig=/etc/kubernetes/admin.conf replace -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
automountServiceAccountToken: false
EOF
