#!/bin/bash
set -e
set -o errexit
set -o pipefail

echo "[ICN] Patching kube-hunter image location"
patch -p1 < ~/update_kube_hunter_image.diff

echo "[ICN] Downloading EMCO k8s"
git clone "https://gerrit.onap.org/r/multicloud/k8s"
patch -d k8s -p1 < ~/update_k8s_installer.diff

echo "[ICN] Installing EMCO k8s"
sudo chown root:root /var/lib/jenkins/.netrc
export CONTAINER_RUNTIME="containerd"
sudo -E k8s/kud/hosting_providers/baremetal/aio.sh
sudo chown jenkins:jenkins /var/lib/jenkins/.netrc
sudo chown jenkins:jenkins -R /var/lib/jenkins/workspace/icn-bluval-daily-master/k8s/kud/hosting_providers/vagrant
# the .netrc chown is a temporary workaround, needs to be fixed in multicloud-k8s
sleep 5

echo "[ICN] Performing Lynis hardening"
ansible-playbook -i k8s/kud/hosting_providers/vagrant/inventory/hosts.ini ~/harden_lynis.yml --become --become-user=root

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

echo "[ICN] Installing docker-ce for run_bluval.sh"
docker_version=$(sudo apt list -a docker-ce | awk '{print $2}' | grep 19.03 | head -1)
sudo apt install -y docker-ce=${docker_version}

echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

echo "[ICN] Patching run_bluval.sh so it doesn't delete .netrc"
sed -i "s/rm -f ~\/.netrc/#rm -f ~\/.netrc/" run_bluval.sh

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
