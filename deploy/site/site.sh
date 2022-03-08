#!/usr/bin/env bash
set -eux -o pipefail

SCRIPTDIR="$(readlink -f $(dirname ${BASH_SOURCE[0]}))"
LIBDIR="$(dirname $(dirname ${SCRIPTDIR}))/env/lib"

source $LIBDIR/common.sh
source $SCRIPTDIR/common.sh

# !!!NOTE!!! THE KEYS USED BELOW ARE FOR TEST PURPOSES ONLY.  DO NOT
# USE THESE OUTSIDE OF THIS ICN VIRTUAL TEST ENVIRONMENT.

function build_istio_root_certs {
    # Create root CA certs for use by Istio in each cluster
    clone_istio_repository
    local -r certs_dir=${SCRIPTDIR}/secrets/certs
    rm -rf ${certs_dir}
    mkdir -p ${certs_dir}
    certs=${ISTIOPATH}/tools/certs
    make -C ${certs} -f Makefile.selfsigned.mk ROOT_CN="EMCO Root CA" ROOTCA_ORG=project-emco.io root-ca
    find ${certs}/root-* -exec cp '{}' ${certs_dir} ';'
}

function build_site_source {
    local -r site_dir=$1
    local -r reuse_credentials=${2:-false}

    # First decrypt the existing site YAML, otherwise we'll be
    # attempting to encrypt it twice below
    if [[ -f ${FLUX_SOPS_PRIVATE_KEY} ]]; then
        gpg --import ${FLUX_SOPS_PRIVATE_KEY}
        for yaml in ${site_dir}/cluster/*/*.yaml ${site_dir}/deployment/*.yaml; do
            sops_decrypt ${yaml} ${site_dir}
        done
    fi

    if ! ${reuse_credentials}; then
        # Generate user password and authorized key in site YAML
        # To login to guest, ssh -i ${site_dir}/id_rsa
        HASHED_PASSWORD=$(mkpasswd --method=SHA-512 --rounds 10000 "mypasswd")
        ssh-keygen -t rsa -N "" -f ${site_dir}/id_rsa <<<y
        SSH_AUTHORIZED_KEY=$(cat ${site_dir}/id_rsa.pub)
        for yaml in ${site_dir}/deployment/*.yaml; do
            sed -i -e 's!hashedPassword: .*!hashedPassword: '"${HASHED_PASSWORD}"'!' ${yaml}
            # Use ! instead of usual / to avoid escaping / in
            # SSH_AUTHORIZED_KEY
            sed -i -e 's!sshAuthorizedKey: .*!sshAuthorizedKey: '"${SSH_AUTHORIZED_KEY}"'!' ${yaml}
        done
    fi

    # Create intermediate CA certs for use by Istio in each cluster
    certs=${ISTIOPATH}/tools/certs
    for yaml in ${site_dir}/deployment/*.yaml; do
        name=$(awk '/clusterName:/ {print $2}' ${yaml})
        if [[ ! -z "${name}" ]]; then
            certs_dir=${SCRIPTDIR}/secrets/certs/$(basename ${site_dir})
            mkdir -p ${certs_dir}
            make -C ${certs} -f Makefile.selfsigned.mk INTERMEDIATE_CN="EMCO Intermediate CA" INTERMEDIATE_ORG=project-emco.io ${name}-cacerts
            cp -r ${certs}/${name} ${certs_dir}
            kubectl create secret generic cacerts -n istio-system --dry-run=client -o yaml \
                --from-file=${certs}/${name}/ca-cert.pem \
                --from-file=${certs}/${name}/ca-key.pem \
                --from-file=${certs}/${name}/root-cert.pem \
                --from-file=${certs}/${name}/cert-chain.pem >${site_dir}/cluster/${name}/istio-cacerts.yaml
        fi
    done

    # Encrypt the site YAML
    for yaml in ${site_dir}/cluster/*/*.yaml ${site_dir}/deployment/*.yaml; do
        sops_encrypt ${yaml} ${FLUX_SOPS_KEY_NAME} ${site_dir}
    done
}

function build_source {
    create_gpg_key ${FLUX_SOPS_KEY_NAME}
    # ONLY FOR TEST ENVIRONMENT: save the private key used
    export_gpg_private_key ${FLUX_SOPS_KEY_NAME} >${FLUX_SOPS_PRIVATE_KEY}

    build_istio_root_certs

    build_site_source ${SCRIPTDIR}/vm-mc
    build_site_source ${SCRIPTDIR}/vm
    build_site_source ${SCRIPTDIR}/pod11 true # re-use existing credentials in site
}

case $1 in
    "create-gpg-key") create_gpg_key $2 ;;
    "sops-encrypt-site") sops_encrypt $2 $3 ;;
    "sops-decrypt-site")
        if [[ $# -eq 2 ]]; then
            sops_decrypt $2
        else
            sops_decrypt $2 $3
        fi
        ;;
    "flux-create-site") flux_create_site $2 $3 $4 $5;;
    "build-source") build_source ;;
    *) cat <<EOF
Usage: $(basename $0) COMMAND

Commands:
  build-source                                  - Rebuild the in-tree site files
  create-gpg-key KEY_NAME                       - Create GPG keypair in local keyring
  sops-encrypt-site SITE_YAML KEY_NAME          - Encrypt SITE_YAML secrets with KEY_NAME
  sops-decrypt-site SITE_YAML [SITE_DIR]        - Decrypt SITE_YAML secrets
  flux-create-site URL BRANCH PATH KEY_NAME     - Create Flux resources to deploy site
EOF
       ;;
esac
