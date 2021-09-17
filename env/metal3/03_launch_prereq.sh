#!/usr/bin/env bash
set -eux -o pipefail

LIBDIR="$(dirname "$PWD")"

source $LIBDIR/lib/logging.sh
source $LIBDIR/lib/common.sh

if [[ $EUID -ne 0 ]]; then
    echo "launch script must be run as root"
    exit 1
fi

function install_ironic_container {
    # set password for mariadb
    mariadb_password=$(echo $(date;hostname)|sha256sum |cut -c-20)

    # Start image downloader container
    docker run -d --net host --privileged --name ipa-downloader \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" "${IPA_DOWNLOADER_IMAGE}" /usr/local/bin/get-resource.sh

    docker wait ipa-downloader

    if [ ! -e "$IRONIC_DATA_DIR/html/images/ironic-python-agent.kernel" ] ||
       [ ! -e "$IRONIC_DATA_DIR/html/images/ironic-python-agent.initramfs" ]; then
        echo "Failed to get ironic-python-agent"
        exit 1
    fi

    # Start dnsmasq, http, mariadb, and ironic containers using same image
    # See this file for env vars you can set, like IP, DHCP_RANGE, INTERFACE
    docker run -d --net host --privileged --name dnsmasq \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/rundnsmasq "${IRONIC_IMAGE}"

    # For available env vars, see:
    docker run -d --net host --privileged --name httpd \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/runhttpd "${IRONIC_IMAGE}"

    # https://github.com/metal3-io/ironic/blob/master/runmariadb.sh
    docker run -d --net host --privileged --name mariadb \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" --entrypoint /bin/runmariadb \
        --env "MARIADB_PASSWORD=$mariadb_password" "${IRONIC_IMAGE}"

    # See this file for additional env vars you may want to pass, like IP and INTERFACE
    docker run -d --net host --privileged --name ironic \
        --env-file "${PWD}/ironic.env" \
        --env "MARIADB_PASSWORD=$mariadb_password" \
        -v "$IRONIC_DATA_DIR:/shared" "${IRONIC_IMAGE}"

    # Start Ironic Inspector
    docker run -d --net host --privileged --name ironic-inspector \
        --env-file "${PWD}/ironic.env" \
        -v "$IRONIC_DATA_DIR:/shared" "${IRONIC_INSPECTOR_IMAGE}"
}

function create_ironic_env {
    cat <<EOF > ${PWD}/ironic.env
PROVISIONING_INTERFACE=provisioning
DHCP_RANGE=172.22.0.10,172.22.0.100
IPA_BASEURI=https://images.rdoproject.org/train/rdo_trunk/current-tripleo
DEPLOY_KERNEL_URL=http://172.22.0.1/images/ironic-python-agent.kernel
DEPLOY_RAMDISK_URL=http://172.22.0.1/images/ironic-python-agent.initramfs
IRONIC_ENDPOINT=http://172.22.0.1:6385/v1/
IRONIC_INSPECTOR_ENDPOINT=http://172.22.0.1:5050/v1/
CACHEURL=http://172.22.0.1/images
IRONIC_FAST_TRACK=false
EOF
}

function install {
    create_ironic_env
    install_ironic_container
}

if [ "$#" -eq 0 ]; then
    install online
elif [ "$1" == "-o" ]; then
    install offline
else
    exit 1
fi
