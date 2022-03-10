#!/bin/bash
set -eu -o pipefail

listen_ip=$1

if [[ -f ${HOME}/.sushy/emulator.pid ]]; then
    if ps -p $(cat ${HOME}/.sushy/emulator.pid); then
	echo sushy-emulator is already started
	exit 0
    fi
fi

# Install prerequisites
if [[ $(which apt-get 2>/dev/null) ]]; then
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y make apache2-utils libvirt-dev ovmf python3-pip
elif [[ $(which yum) ]]; then
    # TODO OVMF doesn't include OVMF_CODE.fd
    sudo yum install -y make httpd-tools libvirt-devel OVMF python3-pip
fi
sudo python3 -m pip install libvirt-python sushy-tools
# Add route to provisioning network - sushy-emulator needs to
# fetch ISOs over this during virtual media boot
dev=$(ip -o addr show to ${listen_ip} | awk '{print $2}')
sudo ip route add 172.22.0.0/24 dev ${dev}
# Configure sushy-emulator
mkdir -p ${HOME}/.sushy
openssl req -x509 -newkey rsa:4096 -keyout ${HOME}/.sushy/key.pem -out ${HOME}/.sushy/cert.pem -sha256 -days 365 -nodes -subj "/CN=${listen_ip}"
htpasswd -c -b -B ${HOME}/.sushy/htpasswd admin password
cat <<EOF >${HOME}/.sushy/emulator.conf
SUSHY_EMULATOR_LISTEN_IP = u'${listen_ip}'
SUSHY_EMULATOR_SSL_CERT = u'${HOME}/.sushy/cert.pem'
SUSHY_EMULATOR_SSL_KEY = u'${HOME}/.sushy/key.pem'
SUSHY_EMULATOR_AUTH_FILE = u'${HOME}/.sushy/htpasswd'
SUSHY_EMULATOR_VMEDIA_VERIFY_SSL = False
EOF
sushy-emulator --config ${HOME}/.sushy/emulator.conf 1>${HOME}/.sushy/emulator-stdout.log 2>${HOME}/.sushy/emulator-stderr.log &
echo $! >${HOME}/.sushy/emulator.pid
