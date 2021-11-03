#!/usr/bin/env bash
set -eux -o pipefail

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

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
