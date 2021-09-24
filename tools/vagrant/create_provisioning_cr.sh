#!/bin/bash
set -eu -o pipefail

num_machines=$1
site=$2
name_prefix=$3

provisioning_cr_path="cmd/bpa-operator/e2etest/test_bmh_provisioning_cr.yaml"

name="${name_prefix}1"
provisioning_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-provisioning']/mac/@address")
cat <<EOF >${provisioning_cr_path}
apiVersion: bpa.akraino.org/v1alpha1
kind: Provisioning
metadata:
  name: provisioning-test-bmh
  labels:
    cluster: test-bmh-cluster
    owner: tester
spec:
  masters:
    - ${name}:
        mac-address: ${provisioning_mac}
EOF
if ((num_machines>1)); then
    cat <<EOF >>${provisioning_cr_path}
  workers:
EOF
    for ((i=2;i<=num_machines;++i)); do
	name="${name_prefix}${i}"
	provisioning_mac=$(virsh -c qemu:///system dumpxml "${site}-${name}" | xmlstarlet sel -t -v "//interface[source/@network='${site}-provisioning']/mac/@address")
	cat <<EOF >>${provisioning_cr_path}
    - ${name}:
        mac-address: ${provisioning_mac}
EOF
    done
fi
cat <<EOF >>${provisioning_cr_path}
  KUDPlugins:
    - emco
EOF
