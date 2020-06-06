#!/bin/bash
set -e
set -o errexit
set -o pipefail

echo "[ICN] Downloading EMCO k8s"
git clone "https://gerrit.onap.org/r/multicloud/k8s"
cp ~/aio.sh k8s/kud/hosting_providers/baremetal/aio.sh
cp ~/installer.sh k8s/kud/hosting_providers/vagrant/installer.sh

echo "[ICN] Installing EMCO k8s"
sudo chown root:root /var/lib/jenkins/.netrc
sudo k8s/kud/hosting_providers/baremetal/aio.sh
sudo chown jenkins:jenkins /var/lib/jenkins/.netrc
sudo chown jenkins:jenkins -R /var/lib/jenkins/workspace/icn-bluval-daily-master/k8s/kud/hosting_providers/vagrant
# the .netrc chown is a temporary workaround, needs to be fixed in multicloud-k8s
sleep 5

echo "[ICN] Patching EMCO k8s security vulnerabilities"
kubectl replace -f - << EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pod-reader
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "false"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:public-info-viewer
rules:
- nonResourceURLs:
  - /livez
  - /readyz
  - /healthz
  verbs:
  - get
EOF
kubectl replace -f - << EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: default
automountServiceAccountToken: false
EOF

echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

echo "[ICN] Patching run_bluval.sh so it doesn't delete .netrc"
sed -i "s/rm -f ~\/.netrc/#rm -f ~\/.netrc/" run_bluval.sh

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
