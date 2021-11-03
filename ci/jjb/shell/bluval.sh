#!/usr/bin/env bash

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -eux -o pipefail

echo "[ICN] Downloading ICN"
git clone "https://gerrit.akraino.org/r/icn"

echo "[ICN] Bringing up test cluster"
function clean_vm {{
    vagrant destroy -f
}}
trap clean_vm EXIT
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
ssh-copy-id -i /var/lib/jenkins/jenkins-rsa -f ${{CLUSTER_SSH_USER}}@${{CLUSTER_MASTER_IP}}

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
