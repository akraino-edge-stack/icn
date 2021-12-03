#!/usr/bin/env bash
set -eu -o pipefail

function _gpg_key_fp {
    gpg --with-colons --list-secret-keys $1 | awk -F: '/fpr/ {print $10;exit}'
}

function create_gpg_key {
    local -r key_name=$1

    # Create an rsa4096 key that does not expire
    gpg --batch --full-generate-key <<EOF
%no-protection
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Expire-Date: 0
Name-Real: ${key_name}
EOF
}

function export_gpg_private_key {
    gpg --export-secret-keys --armor "$(_gpg_key_fp $1)"
}

function sops_encrypt_site {
    local -r site_yaml=$1
    local -r key_name=$2

    local -r site_dir=$(dirname ${site_yaml})
    local -r key_fp=$(_gpg_key_fp ${key_name})

    # Commit the public key to the repository so that team members who
    # clone the repo can encrypt new files
    echo "Creating ${site_dir}/sops.pub.asc with public key used to encrypt secrets"
    gpg --export --armor "${key_fp}" >${site_dir}/sops.pub.asc

    # Add .sops.yaml so users won't have to worry about specifying the
    # proper key for the target cluster or namespace
    echo "Creating ${site_dir}/.sops.yaml SOPS configuration file"
    cat <<EOF > ${site_dir}/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^(bmcPassword|hashedPassword)$
    pgp: ${key_fp}
EOF

    sops --encrypt --in-place --config=${site_dir}/.sops.yaml ${site_yaml}
}

function sops_decrypt_site {
    local -r site_yaml=$1

    local -r site_dir=$(dirname ${site_yaml})
    sops --decrypt --in-place --config=${site_dir}/.sops.yaml ${site_yaml}
}

function flux_create_site {
    local -r url=$1
    local -r branch=$2
    local -r path=$3
    local -r key_name=$4

    local -r source_name="$(basename ${url})-${branch}"
    local -r kustomization_name="${source_name}-site-$(basename ${path})"
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    local -r secret_name="${key_name}-sops-gpg"

    flux create source git ${source_name} --url=${url} --branch=${branch}
    gpg --export-secret-keys --armor "$(_gpg_key_fp ${key_name})" |
	kubectl -n flux-system create secret generic ${secret_name} --from-file=sops.asc=/dev/stdin --dry-run=client -o yaml |
	kubectl apply -f -
    flux create kustomization ${kustomization_name} --path=${path} --source=GitRepository/${source_name} --prune=true \
	 --decryption-provider=sops --decryption-secret=${secret_name}
}
