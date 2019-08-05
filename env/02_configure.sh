#!/usr/bin/env bash
set -xe

source lib/logging.sh
source lib/common.sh

interface_prov=$1
interface_ipmi=$2
ip_impi=$3

if [[ $EUID -ne 0 ]]; then
    echo "confgiure script must be run as root"
    exit 1
fi

function check_inteface_ip() {
	local interface=$1
	local ipaddr=$2

    if [ ! $(ip addr show dev $interface) ]; then
        exit 1
    fi

    local ipv4address=$(ip addr show dev $interface | awk '$1 == "inet" { sub("/.*", "", $2); print $2 }')
    if [ "$ipv4address" != "$ipaddr" ]; then
        exit 1
    fi
}

function configure_kubelet() {
	swapoff -a
	#Todo addition kubelet configuration
}

function configure_kubeadm() {
	#Todo error handing
	kubeadm config images pull --kubernetes-version=$KUBE_VERSION
}

function configure_ironic_interfaces() {
	#Todo later to change the CNI networking for podman networking
	# Add firewall rules to ensure the IPA ramdisk can reach httpd, Ironic and the Inspector API on the host
	if [ "$IRONIC_PROVISIONING_INTERFACE" ]; then
		check_inteface_ip $IRONIC_PROVISIONING_INTERFACE $IRONIC_PROVISIONING_INTERFACE_IP	
	else
		exit 1

	fi

	if [ "$IRONIC_IPMI_INTERFACE" ]; then
        check_inteface_ip $IRONIC_IPMI_INTERFACE $IRONIC_IPMI_INTERFACE_IP
    else
        exit 1
    fi

	for port in 80 5050 6385 ; do
    	if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT > /dev/null 2>&1; then
        	sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p tcp -m tcp --dport $port -j ACCEPT
    	fi
	done

	# Allow ipmi to the bmc processes
	if ! sudo iptables -C INPUT -i $IRONIC_IPMI_INTERFACE -p udp -m udp --dport 6230:6235 -j ACCEPT 2>/dev/null ; then
    	sudo iptables -I INPUT -i $IRONIC_IPMI_INTERFACE -p udp -m udp --dport 6230:6235 -j ACCEPT
	fi

	#Allow access to dhcp and tftp server for pxeboot
	for port in 67 69 ; do
    	if ! sudo iptables -C INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT 2>/dev/null ; then
        	sudo iptables -I INPUT -i $IRONIC_PROVISIONING_INTERFACE -p udp --dport $port -j ACCEPT
    	fi
	done
}

function configure_podman() {
	podman pull $IRONIC_IMAGE
	podman pull $IRONIC_INSPECTOR_IMAGE
	
	mkdir -p "$IRONIC_DATA_DIR/html/images"
	pushd $IRONIC_DATA_DIR/html/images
	
	if [ ! -f ironic-python-agent.initramfs ]; then
		curl --insecure --compressed -L https://images.rdoproject.org/master/rdo_trunk/current-tripleo-rdo/ironic-python-agent.tar | tar -xf -
	fi
	
	if [[ "$BM_IMAGE_URL" && "$BM_IMAGE" ]]; then
    	curl -o ${BM_IMAGE} --insecure --compressed -O -L ${BM_IMAGE_URL}
    	md5sum ${BM_IMAGE} | awk '{print $1}' > ${BM_IMAGE}.md5sum
	fi
	popd
}

function find_record_end () {
        next=$1   # start of record
        last=$2   # end of file
        indent=$3 # indentation of record name (e.g. "eth0")
        let "next++"
        while [ "$next" -lt "$last" ]
        do # get indentation of next line
                i=$(sed -n "$next p" $config_file | grep -o " "| wc -l)
                if [ $i -gt $indent ]; then # next line
                        let "next++"
                else # found end of record
                        let "next--"
                        break
                fi
        done
        echo $next # return last line for this record
}

configure_network () {
	# args: provisioning interface name, IPMI interface name, IPMI IP
	PROV_IF=$1
	PROV_IP="172.22.0.1" # IP for provisioning bridge
	IPMI_IF=$2
	IPMI_IP=$3

	if [[ $# -eq 0 ]]; then
	    echo "You must specify provisioning interface, IPMI interface, and IMPI IP"
	    exit 0
	fi
	# Find default interface name from the route
	# alternate: ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//"
	default_if=$(ip route |grep default | cut -d ' ' -f5)
	echo "default interface: $default_if"

	# Make sure interfaces to add are not the default interface
	if [ "$default_if" == "$PROV_IF" ]; then
        	echo "$PROV_IF is the default interface, do not use"
	        exit 1
	fi
	if [ "$default_if" == "$IPMI_IF" ]; then
        	echo "$IPMI_IF is the default interface, do not use"
	        exit 1
	fi

	#if brctl show | grep "provisioning"; then
        	#echo "deleting provisioning bridge"
        	#ifconfig provisioning down
        	#brctl delbr provisioning
	#
	# look for netplan yaml (must contain default interface)
	config_file=$(grep -H $default_if /etc/netplan/*.yaml | cut -d ':' -f1)
	echo "config file: $config_file"

	# make a backup
	cp $config_file $config_file.bak

	# find the line number with default interface
	ln_def_if=$(grep -n $default_if $config_file | cut -d ':' -f1)
	if [ -z "$ln_def_if" ]; then
        	echo "default interface not found in netplan yaml"
	        exit 1
	fi
	# find indentation of default interface
	indent0=$(sed -n "$ln_def_if p" $config_file |grep -o " " | wc -l)
	# keep indentation
	let indent1=indent0/2
	let indent2=indent1*2
	let indent3=indent1*3
	let indent4=indent1*4

	last_line=$(wc -l < $config_file) # last line in the file

	# find end of the default if record
	def_eor=$(find_record_end $ln_def_if $last_line $indent0)

	# search for prov if
	# use "sed -i "<line number> a\\$line" to append <line> to <file>
	line1=$(grep -n $PROV_IF $config_file | head -n 1 |cut -d ':' -f1)
	if [ -z "$line1" ]; then # not found, add interface
        	rec=$def_eor # append after def if record
	        echo "prov if not found, add after $rec"
	        line=$(printf "%*s%s" $indent2 ' ' "$PROV_IF:")
	        sed -i "$rec a\\$line" $config_file
	        let "rec++"
	        line=$(printf "%*s%s" $indent3 ' ' "dhcp4: false")
	        sed -i "$rec a\\$line" $config_file
	else # delete old config and add new config
        	echo "prov if found on: $line1"
	        eor=$(find_record_end $line1 $last_line $indent0)
	        rec=$(($line1 + 1))
	        echo "delete prov from $rec to $eor"
        	sed -i "$rec,$eor d" $config_file # delete data
	        # add new data
        	rec=$line1
	        line=$(printf "%*s%s" $indent3 ' ' "dhcp4: false")
	        sed -i "$rec a\\$line" $config_file
	fi
	# search for IPMI if
	line1=$(grep -n $IPMI_IF $config_file | head -n 1| cut -d ':' -f1)
	if [ -z "$line1" ]; then # not found, append interface after default
	        # continue appending after prov if
	        let "rec++"
	        echo "add ipmi at $rec"
	        line=$(printf "%*s%s" $indent2 ' ' "$IPMI_IF:")
	        sed -i "$rec a\\$line" $config_file
	        let "rec++"
	        line=$(printf "%*s%s" $indent3 ' ' "addresses:")
	        sed -i "$rec a\\$line" $config_file
	        let "rec++"
	        line=$(printf "%*s%s" $indent4 ' ' "- $IPMI_IP/24")
	        sed -i "$rec a\\$line" $config_file
	else # delete old config, add new config
	        eor=$(find_record_end $line1 $last_line $indent0)
	        rec=$((line1+1))
	        echo "delete ipmi from $rec to $eor"
	        sed -i "$rec,$eor d" $config_file # delete data
	        # add new data
	        rec=$line1
	        echo "append ipmi after $rec"
	        line=$(printf "%*s%s" $indent3 ' ' "addresses:")
	        sed -i "$rec a\\$line" $config_file
	        let "rec++"
	        line=$(printf "%*s%s" $indent4 ' ' "- $IPMI_IP/24")
	        sed -i "$rec a\\$line" $config_file
	fi

	# add provisioning bridge
	bridges=$(grep -n "bridges:" $config_file | head -n 1)
	if [ -z "$bridges" ]; then
        	echo "provisioning bridge not found, adding..."
	        line=$(printf  "%*s%s" $indent1 ' ' "bridges:")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent2 ' ' "provisioning:")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent3 ' ' "interfaces: [$PROV_IF]")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent3 ' ' "dhcp4: false")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent3 ' ' "dhcp6: false")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent3 ' ' "addresses:")
	        echo "$line" >> $config_file
	        line=$(printf "%*s%s" $indent4 ' ' "- $PROV_IP/24")
	        echo "$line" >> $config_file
	else
		echo "provisioning bridge already exits"
	fi
	echo "apply netplan"
	netplan apply
}

configure_kubeadm
configure_kubelet
configure_ironic_interfaces
configure_podman
configure_network interface_prov interface_ipmi ip_ipmi
