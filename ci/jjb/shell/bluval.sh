#!/usr/bin/env bash

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -eux -o pipefail

SCRIPT_DIR="$(readlink -f $(dirname ${{BASH_SOURCE[0]}}))"

echo "[ICN] Downloading ICN"
git clone "https://gerrit.akraino.org/r/icn"

echo "[ICN] Bringing up test cluster"
function clean_vm {{
    pushd ${{SCRIPT_DIR}}/icn
    vagrant destroy -f
    popd
}}
trap clean_vm EXIT
pushd icn
# TODO Improve VM performance by only using cores on the same node
#sed -i -e '/^\s\+libvirt.cpus/!b' -e "h;s/\S.*/libvirt.cpuset = '0-21,44-65'/;H;g" Vagrantfile
vagrant destroy -f
vagrant up --no-parallel
vagrant ssh jump -c "
set -exuf
cd /icn
sudo su -c 'make jump_server vm_cluster'
"
popd

echo "[ICN] Installing jenkins identity into test cluster"
cp ${{SCRIPT_DIR}}/icn/deploy/site/vm/id_rsa site-vm-rsa
chmod 0600 site-vm-rsa
ssh-keygen -f ${{CLUSTER_SSH_KEY}} -y > ${{CLUSTER_SSH_KEY}}.pub
ssh-copy-id -i ${{CLUSTER_SSH_KEY}} -f ${{CLUSTER_SSH_USER}}@${{CLUSTER_MASTER_IP}} -o IdentityFile=site-vm-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

echo "[ICN] Patching kube-hunter image location"
cat <<'EOF' | patch -p1
diff --git a/tests/variables.yaml b/tests/variables.yaml
index fa3fe71..c54f37f 100644
--- a/tests/variables.yaml
+++ b/tests/variables.yaml
@@ -82,3 +82,7 @@ dns_domain: cluster.local                     # cluster's DNS domain
 # NONE, WARN, INFO, DEBUG, and TRACE.
 # Default is INFO
 loglevel: INFO
+
+kube_hunter:
+  path: 'aquasec'
+  name: 'kube-hunter:edge'
EOF

echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

echo "[ICN] Patching run_bluval.sh so it doesn't delete .netrc"
sed -i "s/rm -f ~\/.netrc/#rm -f ~\/.netrc/" run_bluval.sh

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
