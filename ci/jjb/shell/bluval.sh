#!/bin/bash
set -e
set -o errexit
set -o pipefail

echo "[ICN] Downloading run_bluval.sh from upstream ci-management"
wget --read-timeout=10 --timeout=10 --waitretry=10 -t 10 https://raw.githubusercontent.com/akraino-edge-stack/ci-management/master/jjb/shell/run_bluval.sh

echo "[ICN] Patching run_bluval.sh so it doesn't delete .netrc"
sed -i "s/rm -f ~\/.netrc/#rm -f ~\/.netrc/" run_bluval.sh

echo "[ICN] Executing run_bluval.sh"
/bin/bash run_bluval.sh
