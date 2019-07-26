#!/bin/bash
set -ex

LIBDIR="$(dirname "$(dirname "$(dirname "$PWD")")")"

eval "$(go env)"

BM_OPERATOR="${BM_OPERATOR:-https://github.com/metal3-io/baremetal-operator.git}"

source $LIBDIR/env/lib/common.sh

function get_default_inteface_ipaddress() {
    local _ip=$1
    local _default_interface=$(awk '$2 == 00000000 { print $1 }' /proc/net/route)
    local _ipv4address=$(ip addr show dev $_default_interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    eval $_ip="'$_ipv4address'"
}

create_ssh_key() {
	#ssh key for compute node to communicate back to bootstrap server
	mkdir -p $BUILD_DIR/ssh_key
	ssh-keygen -C "compute.icn.akraino.lfedge.org" -f $BUILD_DIR/ssh_key/id_rsa
	cat $BUILD_DIR/ssh_key/id_rsa.pub >> $HOME/.ssh/authorized_keys
}

set_compute_key() {
_SSH_LOCAL_KEY=$(cat $BUILD_DIR/ssh_key/id_rsa)
cat << EOF
write_files:
- path: /opt/ssh_id_rsa
  owner: root:root
  permissions: '0600'
  content: |
    $_SSH_LOCAL_KEY
EOF
}

provision_compute_node() {
	IMAGE_URL=http://172.22.0.1/images/${BM_IMAGE}
	IMAGE_CHECKSUM=http://172.22.0.1/images/${BM_IMAGE}.md5sum

	if [ ! -d $GOPATH/src/github.com/metal3-io/baremetal-operator ]; then
		go get github.com/metal3-io/baremetal-operator
	fi

	go run $GOPATH/src/github.com/metal3-io/baremetal-operator/cmd/make-bm-worker/main.go \
           -address "ipmi://$COMPUTE_IPMI_ADDRESS" \
		   -user "$COMPUTE_IPMI_USER" \
           -password "$COMPUTE_IPMI_PASSWORD" \
           "$COMPUTE_NODE_NAME" > $COMPUTE_NODE_NAME-bm-node.yaml

	printf "  image:" >> $COMPUTE_NODE_NAME-bm-node.yaml
	printf "\n    url: ""%s" "$IMAGE_URL" >> $COMPUTE_NODE_NAME-bm-node.yaml
	printf "\n    checksum: ""%s" "$IMAGE_CHECKSUM" >> $COMPUTE_NODE_NAME-bm-node.yaml
	printf "\n  userData:" >> $COMPUTE_NODE_NAME-bm-node.yaml
	printf "\n    name: ""%s" "$COMPUTE_NODE_NAME""-user-data" >> $COMPUTE_NODE_NAME-bm-node.yaml
	printf "\n    namespace: metal3\n" >> $COMPUTE_NODE_NAME-bm-node.yaml
	kubectl apply -f $COMPUTE_NODE_NAME-bm-node.yaml
}

deprovision_compute_node() {
	kubectl patch baremetalhost $COMPUTE_NODE_NAME -n metal3 --type merge \
    -p '{"spec":{"image":{"url":"","checksum":""}}}'
}

set_compute_ssh_config() {
get_default_inteface_ipaddress default_addr
cat << EOF
- path: /root/.ssh/config
  owner: root:root
  permissions: '0600'
  content: |
    Host bootstrapmachine $default_addr
    HostName $default_addr
    IdentityFile /opt/ssh_id_rsa
    User $USER
- path: /etc/apt/sources.list
  owner: root:root
  permissions: '0665'
  content: |
	deb [trusted=yes] ssh://$USER@$default_addr:$LOCAL_APT_REPO ./
EOF
}

create_userdata() {
	printf "#cloud-config\n" > userdata.yaml
	if [ -n "$COMPUTE_NODE_PASSWORD" ]; then
		printf "password: ""%s" "$COMPUTE_NODE_PASSWORD" >> userdata.yaml
		printf "\nchpasswd: {expire: False}\n" >> userdata.yaml
		printf "ssh_pwauth: True\n" >> userdata.yaml
	fi

	if [ -n "$COMPUTE_NODE_FQDN" ]; then
		printf "fqdn: ""%s" "$COMPUTE_NODE_FQDN" >> userdata.yaml
		printf "\n" >> userdata.yaml
	fi

	printf "ssh_authorized_keys:\n  - " >> userdata.yaml

	if [ -f $HOME/.ssh/id_rsa.pub ]; then
		yes y | ssh-keygen -t rsa -N "" -f $HOME/.ssh/id_rsa
	fi

	cat $HOME/.ssh/id_rsa.pub >> userdata.yaml
	printf "\n" >> userdata.yaml
}

apply_userdata_credential() {
	cat <<EOF > ./$COMPUTE_NODE_NAME-user-data.yaml
apiVersion: v1
data:
  userData: $(base64 -w 0 userdata.yaml)
kind: Secret
metadata:
  name: $COMPUTE_NODE_NAME-user-data
  namespace: metal3
type: Opaque
EOF
	kubectl apply -n metal3 -f $COMPUTE_NODE_NAME-user-data.yaml
}

launch_baremetal_operator() {
	if [ ! -d $GOPATH/src/github.com/metal3-io/baremetal-operator ]; then
        go get github.com/metal3-io/baremetal-operator
    fi

	pushd $GOPATH/src/github.com/metal3-io/baremetal-operator
		make deploy
	popd
		
}

if [ "$1" == "launch" ]; then
    launch_baremetal_operator
    exit 0
fi

if [ "$1" == "deprovision" ]; then
    deprovision_compute_node
    exit 0
fi

if [ "$1" == "provision" ]; then
    create_userdata
	apply_userdata_credential
	provision_compute_node
    exit 0
fi


echo "Usage: metal3.sh"
echo "launch      - Launch the metal3 operator"
echo "provision   - provision baremetal node as specified in common.sh"
echo "deprovision - deprovision baremetal node as specified in common.sh"
exit 1

#Following code is tested for the offline mode
#Will be intergrated for the offline mode for ICNi v.0.1.0 beta
#create_ssh_key
#create_userdata
#set_compute_key
#set_compute_ssh_config
