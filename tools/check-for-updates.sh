#!/bin/bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"

BRANCH=${1:-master}

cat <<EOF
Checking installed versions against available versions in ${BRANCH}...

EOF

${SCRIPTDIR}/software-bom.sh from-installed >installed-versions.md
curl -sL 'https://gerrit.akraino.org/r/gitweb?p=icn.git;a=blob_plain;f=doc/software-bom.md;hb=refs/heads/'${BRANCH} | sed '/Compute cluster/Q' >available-versions.md


if diff installed-versions.md available-versions.md >/dev/null; then
    cat <<EOF
No updates available.
EOF
else
cat <<EOF
Updates of the jump server components may be available. Please refer
to doc/upgrading.md for instructions on upgrading the component(s).

EOF
    diff -u0 installed-versions.md available-versions.md | awk '{print "  " $0}'
fi


