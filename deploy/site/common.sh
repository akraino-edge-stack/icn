#!/usr/bin/env bash
set -eu -o pipefail

FLUX_SOPS_KEY_NAME=${FLUX_SOPS_KEY_NAME:-"icn-site-vm"}
FLUX_SOPS_PRIVATE_KEY="$(readlink -f $(dirname ${BASH_SOURCE[0]}))/secrets/sops.asc"
SITE_NAMESPACE="${SITE_NAMESPACE:-metal3}"

function _gpg_key_fp {
    gpg --with-colons --fingerprint $1 | awk -F: '/fpr/ {print $10;exit}'
}

function sops_encrypt {
    local -r yaml=$1
    local -r yaml_dir=$(dirname ${yaml})

    local -r key_name=$2
    local -r key_fp=$(_gpg_key_fp ${key_name})

    local site_dir=${yaml_dir}
    if [[ $# -eq 3 ]]; then
	site_dir=$3
    fi

    # Commit the public key to the repository so that team members who
    # clone the repo can encrypt new files
    echo "Creating ${yaml_dir}/sops.pub.asc with public key used to encrypt secrets"
    gpg --export --armor "${key_fp}" >${site_dir}/sops.pub.asc

    # Add .sops.yaml so users won't have to worry about specifying the
    # proper key for the target cluster or namespace
    echo "Creating ${site_dir}/.sops.yaml SOPS configuration file"
    encrypted_regex="(bmcPassword|ca-key.pem|decryptionSecret|hashedPassword|emcoPassword|rootPassword)"
    cat <<EOF > ${site_dir}/.sops.yaml
creation_rules:
  - path_regex: .*.yaml
    encrypted_regex: ^${encrypted_regex}$
    pgp: ${key_fp}
EOF

    if [[ $(grep -c $(echo ${encrypted_regex} | sed -e 's/(/\\(/g' -e 's/|/\\|/g' -e 's/)/\\)/') ${yaml}) -ne 0 ]]; then
	sops --encrypt --in-place --config=${site_dir}/.sops.yaml ${yaml}
    fi
}

function sops_decrypt {
    local -r yaml=$1
    local -r yaml_dir=$(dirname ${yaml})
    local site_dir=${yaml_dir}
    if [[ $# -eq 2 ]]; then
	site_dir=$2
    fi

    if [[ $(grep -c "^sops:" ${yaml}) -ne 0 ]]; then
	sops --decrypt --in-place --config=${site_dir}/.sops.yaml ${yaml}
    fi
}

function _site_source_name {
    local -r url=$1
    local -r branch=$2
    # Only alphanumeric and '-' are allowed in resource names
    echo $(basename ${url})-${branch} | tr -d -c 'A-Za-z0-9-'
}

function _site_kustomization_name {
    local -r url=$1
    local -r branch=$2
    local -r path=$3
    # Only alphanumeric and '-' are allowed in resource names
    echo $(_site_source_name ${url} ${branch})-site-$(basename ${path})  | tr -d -c 'A-Za-z0-9-'
}

function flux_create_site {
    local -r url=$1
    local -r branch=$2
    local -r path=$3
    local -r key_name=$4

    local -r source_name=$(_site_source_name ${url} ${branch})
    local -r kustomization_name=$(_site_kustomization_name ${url} ${branch} ${path})
    local -r key_fp=$(gpg --with-colons --list-secret-keys ${key_name} | awk -F: '/fpr/ {print $10;exit}')
    local -r secret_name="${key_name}-sops-gpg"

    flux create source git ${source_name} --url=${url} --branch=${branch}
    gpg --export-secret-keys --armor "$(_gpg_key_fp ${key_name})" |
	kubectl -n flux-system create secret generic ${secret_name} --from-file=sops.asc=/dev/stdin --dry-run=client -o yaml |
	kubectl apply -f -
    kubectl create namespace ${SITE_NAMESPACE} --dry-run=client -o yaml | kubectl apply -f -
    flux create kustomization ${kustomization_name} --target-namespace=${SITE_NAMESPACE} --path=${path} --source=GitRepository/${source_name} --prune=true \
	 --decryption-provider=sops --decryption-secret=${secret_name}
}

function site_deploy {
    flux_create_site ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH} ${FLUX_SOPS_KEY_NAME}
}

function site_clean {
    kubectl -n flux-system delete kustomization $(_site_kustomization_name ${SITE_REPO} ${SITE_BRANCH} ${SITE_PATH})
}

function _is_cluster_ready {
    for yaml in ${SCRIPTDIR}/deployment/*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	if [[ ! -z ${name} ]]; then
	    if [[ $(kubectl -n ${SITE_NAMESPACE} get cluster ${name} -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}') != "True" ]]; then
		return 1
	    fi
	fi
    done
}

function _is_control_plane_ready {
    # Checking the Cluster resource status is not sufficient, it
    # reports the control plane as ready before the nodes forming the
    # control plane are ready
    for yaml in ${SCRIPTDIR}/deployment/*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	if [[ ! -z ${name} ]]; then
	    local replicas=$(kubectl -n ${SITE_NAMESPACE} get kubeadmcontrolplane ${name} -o jsonpath='{.spec.replicas}')
	    if [[ $(kubectl --kubeconfig=${BUILDDIR}/${name}-admin.conf get nodes -l node-role.kubernetes.io/control-plane -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{"\n"}{end}' | grep -c True) != ${replicas} ]]; then
		return 1
	    fi
	fi
    done
}

function site_wait_for_all_ready {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for _is_cluster_ready
    for yaml in ${SCRIPTDIR}/deployment/*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	if [[ ! -z ${name} ]]; then
	    clusterctl -n ${SITE_NAMESPACE} get kubeconfig ${name} >${BUILDDIR}/${name}-admin.conf
	    chmod 600 ${BUILDDIR}/${name}-admin.conf
	fi
    done
    wait_for _is_control_plane_ready
}

function site_insert_control_plane_network_identity_into_ssh_config {
    # This enables logging into the control plane machines from this
    # machine without specifying the identify file on the command line

    if [[ ! $(which ipcalc) ]]; then
        apt-get install -y ipcalc
    fi

    # Create ssh config if it doesn't exist
    mkdir -p ${HOME}/.ssh && chmod 700 ${HOME}/.ssh
    touch ${HOME}/.ssh/config
    chmod 600 ${HOME}/.ssh/config
    # Add the entry for the control plane network, host value in ssh
    # config is a wildcard
    for yaml in ${SCRIPTDIR}/deployment/*.yaml; do
	name=$(awk '/name:/ {NAME=$2} /chart: deploy\/cluster/ {print NAME; exit}' ${yaml})
	if [[ ! -z ${name} ]]; then
	    endpoint=$(helm -n ${SITE_NAMESPACE} get values -a ${name} | awk '/controlPlaneEndpoint:/ {print $2}')
	    prefix=$(helm -n ${SITE_NAMESPACE} get values -a ${name} | awk '/controlPlanePrefix:/ {print $2}')
	    host=$(ipcalc ${endpoint}/${prefix} | awk '/Network:/ {sub(/\.0.*/,".*"); print $2}')
	    if [[ $(grep -c "Host ${host}" ${HOME}/.ssh/config) != 0 ]]; then
		sed -i -e '/Host '"${host}"'/,+3 d' ${HOME}/.ssh/config
	    fi
	    cat <<EOF >>${HOME}/.ssh/config
Host ${host}
  IdentityFile ${SCRIPTDIR}/id_rsa
  StrictHostKeyChecking no
  UserKnownHostsFile /dev/null
EOF
	fi
    done
    # Add the identity to authorized keys on this host to enable ssh
    # logins via its control plane address
    authorized_key=$(cat ${SCRIPTDIR}/id_rsa.pub)
    sed -i -e '\!'"${authorized_key}"'!d' ${HOME}/.ssh/authorized_keys
    cat ${SCRIPTDIR}/id_rsa.pub >> ~/.ssh/authorized_keys
}

function _is_cluster_deleted {
    for yaml in ${SCRIPTDIR}/deployment/*.yaml; do
	name=$(awk '/clusterName:/ {print $2}' ${yaml})
	if [[ ! -z ${name} ]]; then
	    if kubectl -n ${SITE_NAMESPACE} get cluster ${name}; then
		return 1
	    fi
	fi
    done
}

function site_wait_for_all_deleted {
    WAIT_FOR_INTERVAL=60s
    WAIT_FOR_TRIES=30
    wait_for _is_cluster_deleted
}
