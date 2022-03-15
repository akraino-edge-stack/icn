#!/usr/bin/env bash

# Ensure we fail the job if any steps fail
# Disable 'globbing'
set -eux -o pipefail

function clone_icn {
    echo "[ICN] Downloading ICN"
    git clone "https://gerrit.akraino.org/r/icn" ${WORKSPACE}/icn
}

function create_sut {
    trap destroy_sut EXIT

    echo "[ICN] Bringing up test cluster"
    pushd ${WORKSPACE}/icn
    # TODO Improve VM performance by only using cores on the same node
    #sed -i -e '/^\s\+libvirt.cpus/!b' -e "h;s/\S.*/libvirt.cpuset = '0-21,44-65'/;H;g" Vagrantfile
    ./tools/vagrant/destroy.rb
    vagrant up --no-parallel
    vagrant ssh jump -c "
set -exuf
cd /icn
sudo su -c 'make jump_server vm_cluster'
"
    popd
}

function destroy_sut {
    pushd ${WORKSPACE}/icn
    ./tools/vagrant/destroy.rb
    popd
}

function install_jenkins_identity_into_sut {
    echo "[ICN] Installing jenkins identity into test cluster"
    cp ${WORKSPACE}/icn/deploy/site/vm/id_rsa site-vm-rsa
    chmod 0600 site-vm-rsa
    ssh-keygen -f ${CLUSTER_SSH_KEY} -y > ${CLUSTER_SSH_KEY}.pub
    ssh-copy-id -i ${CLUSTER_SSH_KEY} -f ${CLUSTER_SSH_USER}@${CLUSTER_MASTER_IP} -o IdentityFile=site-vm-rsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null
}

function patch_validation {
    echo "[ICN] Patching validation repository"
    # The conformance (sonobuoy) test is not required by the security
    # scan, and latest kube-hunter is needed to support K8s 1.21
    cat <<'EOF' | patch -p1
diff --git a/bluval/bluval-icn.yaml b/bluval/bluval-icn.yaml
index 9d190bc..0b0e5fa 100644
--- a/bluval/bluval-icn.yaml
+++ b/bluval/bluval-icn.yaml
@@ -15,10 +15,6 @@ blueprint:
             optional: "False"

     k8s: &k8s
-        -
-            name: conformance
-            what: conformance
-            optional: "False"
         -
             name: kube-hunter
             what: kube-hunter
diff --git a/bluval/volumes.yaml b/bluval/volumes.yaml
index 6c48e65..dc0ea87 100644
--- a/bluval/volumes.yaml
+++ b/bluval/volumes.yaml
@@ -46,6 +46,9 @@ volumes:
     openrc:
         local: ''
         target: '/root/openrc'
+    oval_ubuntu_20:
+        local: ''
+        target: '/opt/akraino/validation/tests/os/vuls/oval_ubuntu_20.sqlite3'

 # parameters that will be passed to the container at each layer
 layers:
@@ -54,6 +57,7 @@ layers:
         - custom_variables_file
         - blueprint_dir
         - results_dir
+        - oval_ubuntu_20
     hardware:
         - ssh_key_dir
     os:
diff --git a/tests/variables.yaml b/tests/variables.yaml
index fa3fe71..d642c2c 100644
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
}

function download_oval_ubuntu_20 {
    echo "[ICN] Downloading OVAL for Ubuntu 20"
    mkdir -p ${WORKSPACE}/vuls
    docker run --rm --net=host -v ${WORKSPACE}/vuls:/opt/akraino/validation/tests/os/vuls akraino/validation:os-amd64-latest /bin/sh -c '/root/go/bin/goval-dictionary fetch-ubuntu -dbpath /opt/akraino/validation/tests/os/vuls/oval_ubuntu_20.sqlite3 20'
}

function run_validation {
    echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
    wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

    echo "[ICN] Patching run_bluval.sh"
    cat <<'EOF' | patch -p3
diff --git a/jjb/shell/run_bluval.sh b/jjb/shell/run_bluval.sh
index 75d20eb..dbfad03 100755
--- a/jjb/shell/run_bluval.sh
+++ b/jjb/shell/run_bluval.sh
@@ -148,6 +148,7 @@
     -e "/custom_variables_file/{n; s@local: ''@local: '$cwd/tests/variables.yaml'@}" \
     -e "/blueprint_dir/{n; s@local: ''@local: '$cwd/bluval/'@}" \
     -e "/results_dir/{n; s@local: ''@local: '$results_dir'@}" \
+    -e "/oval_ubuntu_20/{n; s@local: ''@local: '$cwd/vuls/oval_ubuntu_20.sqlite3'@}" \
     "$volumes_path"

 if [ -n "$ssh_key" ]
@@ -177,6 +178,7 @@
 then
     options+=" -P"
 fi
+options+=" -t amd64-latest"

 set +e
 if python3 --version > /dev/null; then
@@ -209,4 +211,3 @@
     rm results.zip
 fi

-rm -f ~/.netrc
EOF

    echo "[ICN] Executing run_bluval.sh"
    /bin/bash run_bluval.sh
}

clone_icn
create_sut
install_jenkins_identity_into_sut
download_oval_ubuntu_20
patch_validation
run_validation
