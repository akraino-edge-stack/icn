#!/bin/bash
set -e
set -o errexit
set -o pipefail

echo "[ICN] Downloading EMCO k8s"
git clone "https://gerrit.onap.org/r/multicloud/k8s"
cp ~/aio.sh k8s/kud/hosting_providers/baremetal/aio.sh
cp ~/installer.sh k8s/kud/hosting_providers/vagrant/installer.sh

echo "[ICN] Installing EMCO k8s"
k8s/kud/hosting_providers/baremetal/aio.sh

echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

echo "[ICN] Patching run_bluval.sh so it doesn't delete .netrc"
sed -i "s/rm -f ~\/.netrc/#rm -f ~\/.netrc/" run_bluval.sh

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
