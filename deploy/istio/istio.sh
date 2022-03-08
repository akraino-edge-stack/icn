#!/usr/bin/env bash
set -eEux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

function test_setup {
    clone_istio_repository

    # Create a temporary kubeconfig file for the tests
    cluster_name=${CLUSTER_1_NAME:-management}
    local -r cluster_1_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    clusterctl -n metal3 get kubeconfig ${cluster_name} >${cluster_1_kubeconfig}
    cluster_name=${CLUSTER_2_NAME:-compute}
    local -r cluster_2_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    clusterctl -n metal3 get kubeconfig ${cluster_name} >${cluster_2_kubeconfig}

    # Deploy sleep on cluster-1
    kubectl --kubeconfig=${cluster_1_kubeconfig}  create namespace foo
    kubectl --kubeconfig=${cluster_1_kubeconfig} label namespace foo istio-injection=enabled
    cat <<EOF | kubectl --kubeconfig=${cluster_1_kubeconfig} apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:privileged-foo
  namespace: foo
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:privileged
subjects:
- kind: Group
  name: system:serviceaccounts:foo
  apiGroup: rbac.authorization.k8s.io
EOF
    kubectl --kubeconfig=${cluster_1_kubeconfig} apply -n foo -f ${ISTIOPATH}/samples/sleep/sleep.yaml --wait

    # Deploy httpbin on cluster-2
    kubectl --kubeconfig=${cluster_2_kubeconfig} create namespace bar
    kubectl --kubeconfig=${cluster_2_kubeconfig} label namespace bar istio-injection=enabled
    cat <<EOF | kubectl --kubeconfig=${cluster_2_kubeconfig} apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: psp:privileged-bar
  namespace: bar
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: psp:privileged
subjects:
- kind: Group
  name: system:serviceaccounts:bar
  apiGroup: rbac.authorization.k8s.io
EOF
    kubectl --kubeconfig=${cluster_2_kubeconfig} apply -n bar -f ${ISTIOPATH}/samples/httpbin/httpbin.yaml --wait

    # Create service entry for httpbin on cluster-1
    cat <<EOF | kubectl --kubeconfig=${cluster_1_kubeconfig} apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-bar
  namespace: foo
spec:
  hosts:
  # DNS name selected for the service
  - httpbin.bar.cluster2
  # Treat remote cluster services as part of the service mesh
  # as all clusters in the service mesh share the same root of trust.
  location: MESH_INTERNAL
  ports:
  - name: tcp
    number: 8000
    protocol: TCP
  resolution: DNS
  addresses:
  # the IP address to which httpbin.bar.cluster2 will resolve to
  # must be unique for each remote service, within a given cluster.
  # This address need not be routable. Traffic for this IP will be captured
  # by the sidecar and routed appropriately.
  - 240.0.0.2
  endpoints:
  # This is the routable address of the ingress gateway in cluster2 that
  # sits in front of sleep.foo service. Traffic from the sidecar will be
  # routed to this address.
  - address: $(kubectl --kubeconfig=${cluster_2_kubeconfig} config view | awk -F[/:] '/server/ {print $5}')
    ports:
      tcp: 32001 # Nodeport for istio-ingressgateway for port 15433
EOF

    # Create DestinationRule for httpbin on cluster-1
    cat <<EOF | kubectl --kubeconfig=${cluster_1_kubeconfig} apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: httpbin-dr
  namespace: foo
spec:
  host: httpbin.bar.cluster2
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF

    # Create Gateway resource on cluster-2
    cat <<EOF | kubectl --kubeconfig=${cluster_2_kubeconfig} apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: httpbin-gateway
  namespace: istio-system
spec:
  selector:
    istio: ingressgateway
  servers:
    - port:
        number: 15443
        name: tls
        protocol: TLS
      tls:
        mode: AUTO_PASSTHROUGH
      hosts:
        - "httpbin.bar.cluster2"
EOF

    # Create ServiceEntry on cluster-2 that is required to map the
    # remote fqdn to local fqdn
    cat <<EOF | kubectl --kubeconfig=${cluster_2_kubeconfig} apply -f -
apiVersion: networking.istio.io/v1alpha3
kind: ServiceEntry
metadata:
  name: httpbin-remote
  namespace: istio-system # must be in same namespace as gateway
spec:
  resolution: DNS
  location: MESH_INTERNAL
  ports:
  - name: tcp
    number: 8000
    protocol: TCP
  exportTo:
  - .
  hosts:
  - "httpbin.bar.cluster2"
  endpoints:
  - address: httpbin.bar.svc.cluster.local
EOF

    # Create DestinationRule and Virtual Service on cluster-2
    cat <<EOF | kubectl --kubeconfig=${cluster_2_kubeconfig} apply -f -
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: httpbin-dr
  namespace: istio-system
spec:
  host: "httpbin.bar.cluster2"
  trafficPolicy:
    tls:
      mode: ISTIO_MUTUAL
EOF
}

function httpbin_accessible_from_sleep_service {
    cluster_name=${CLUSTER_1_NAME:-management}
    local -r cluster_1_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    local -r sleep_pod=$(kubectl --kubeconfig=${cluster_1_kubeconfig} get -n foo pod -l app=sleep -o jsonpath={.items..metadata.name})
    kubectl --kubeconfig=${cluster_1_kubeconfig} exec ${sleep_pod} -n foo -c sleep -- curl -I httpbin.bar.cluster2:8000/headers
}

function test_teardown {
    cluster_name=${CLUSTER_1_NAME:-management}
    local -r cluster_1_kubeconfig="${BUILDDIR}/${cluster_name}.conf"
    cluster_name=${CLUSTER_2_NAME:-compute}
    local -r cluster_2_kubeconfig="${BUILDDIR}/${cluster_name}.conf"

    kubectl --kubeconfig=${cluster_2_kubeconfig} -n istio-system delete DestinationRule httpbin-dr --ignore-not-found
    kubectl --kubeconfig=${cluster_2_kubeconfig} -n istio-system delete ServiceEntry httpbin-remote --ignore-not-found
    kubectl --kubeconfig=${cluster_2_kubeconfig} -n istio-system delete Gateway httpbin-gateway --ignore-not-found

    kubectl --kubeconfig=${cluster_1_kubeconfig} -n foo delete DestinationRule httpbin-dr --ignore-not-found
    kubectl --kubeconfig=${cluster_1_kubeconfig} -n foo delete ServiceEntry httpbin-bar --ignore-not-found

    kubectl --kubeconfig=${cluster_2_kubeconfig} -n bar delete -f ${ISTIOPATH}/samples/httpbin/httpbin.yaml --ignore-not-found
    kubectl --kubeconfig=${cluster_2_kubeconfig} -n bar delete RoleBinding psp:privileged-bar --ignore-not-found
    kubectl --kubeconfig=${cluster_2_kubeconfig} delete namespace bar --ignore-not-found

    kubectl --kubeconfig=${cluster_1_kubeconfig} -n foo delete -f ${ISTIOPATH}/samples/sleep/sleep.yaml --ignore-not-found
    kubectl --kubeconfig=${cluster_1_kubeconfig} -n foo delete RoleBinding psp:privileged-foo --ignore-not-found
    kubectl --kubeconfig=${cluster_1_kubeconfig} delete namespace foo --ignore-not-found
}

function test_istio {
    test_setup

    WAIT_FOR_INTERVAL=10s
    WAIT_FOR_TRIES=6
    wait_for httpbin_accessible_from_sleep_service

    test_teardown
}

case $1 in
    "test") test_istio ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

The "test" command looks for the CLUSTER_1_NAME and CLUSTER_2_NAME
variables in the environment (default: "management" and "compute").
This should be the name of the Cluster resources to execute the tests
in.

Commands:
  test          - Test Istio
EOF
       ;;
esac
