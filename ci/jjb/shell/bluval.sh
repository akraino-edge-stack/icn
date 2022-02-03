#!/usr/bin/env bash

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -eux -o pipefail

echo "[ICN] Downloading ICN"
git clone "https://gerrit.akraino.org/r/icn" ${WORKSPACE}/icn

echo "[ICN] Bringing up test cluster"
function clean_vm {
    pushd ${WORKSPACE}/icn
    vagrant destroy -f
    popd
}
trap clean_vm EXIT
pushd ${WORKSPACE}/icn
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
cp ${WORKSPACE}/icn/deploy/site/vm/id_rsa site-vm-rsa
chmod 0600 site-vm-rsa
ssh-keygen -f ${CLUSTER_SSH_KEY} -y > ${CLUSTER_SSH_KEY}.pub
ssh-copy-id -i ${CLUSTER_SSH_KEY} -f ${CLUSTER_SSH_USER}@${CLUSTER_MASTER_IP} -o IdentityFile=site-vm-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null

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

echo "[ICN] Patching run_bluval.sh"
cat <<'EOF' | patch -p3
diff --git a/jjb/shell/run_bluval.sh b/jjb/shell/run_bluval.sh
index 75d20eb..dbfad03 100755
--- a/jjb/shell/run_bluval.sh
+++ b/jjb/shell/run_bluval.sh
@@ -177,6 +177,7 @@ if [ "$pull" == "true" ] || [ "$PULL" == "yes" ]
 then
     options+=" -P"
 fi
+options+=" -t amd64-latest"

 set +e
 if python3 --version > /dev/null; then
@@ -209,4 +210,3 @@ else
     rm results.zip
 fi

-rm -f ~/.netrc
EOF

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
