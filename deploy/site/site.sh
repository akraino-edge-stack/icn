#!/usr/bin/env bash
set -eu -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/common.sh

case $1 in
    "create-gpg-key") create_gpg_key $2 ;;
    "sops-encrypt-site") sops_encrypt $2 $3 ;;
    "sops-decrypt-site") sops_decrypt $2 ;;
    "flux-create-site") flux_create_site $2 $3 $4 $5;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  create-gpg-key KEY_NAME			- Create GPG keypair in local keyring
  sops-encrypt-site SITE_YAML KEY_NAME		- Encrypt SITE_YAML secrets with KEY_NAME
  sops-decrypt-site SITE_YAML			- Decrypt SITE_YAML secrets
  flux-create-site URL BRANCH PATH KEY_NAME	- Create Flux resources to deploy site
EOF
       ;;
esac
