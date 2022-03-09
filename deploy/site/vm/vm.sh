#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname $(dirname ${SCRIPTDIR})))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/../common.sh

BUILDDIR=${SCRIPTDIR/deploy/build}
mkdir -p ${BUILDDIR}

SITE_REPO=${SITE_REPO:-"https://gerrit.akraino.org/r/icn"}
SITE_BRANCH=${SITE_BRANCH:-"master"}
SITE_PATH=${SITE_PATH:-"deploy/site/vm/deployment"}

case $1 in
    "clean") site_clean ;;
    "deploy")
	gpg --import ${FLUX_SOPS_PRIVATE_KEY}
	site_deploy ;;
    "wait")
	site_wait_for_all_ready
	site_insert_control_plane_network_identity_into_ssh_config
	;;
    "wait-clean") site_wait_for_all_deleted ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  clean         - Remove the site
  deploy        - Deploy the site
  wait          - Wait for the site to be ready
  wait-clean    - Wait for the site to be removed
EOF
       ;;
esac
