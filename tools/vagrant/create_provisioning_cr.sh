#!/bin/bash
set -eu -o pipefail

site=$1; shift

provisioning_cr_path="cmd/bpa-operator/e2etest/test_bmh_provisioning_cr.yaml"

name=$1; shift
ipmi_port=$1; shift
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
if (("$#")); then
    cat <<EOF >>${provisioning_cr_path}
  workers:
EOF
    while (("$#")); do
	name=$1; shift
	ipmi_port=$1; shift
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
