#!/usr/bin/env bash
set -eux -o pipefail

function append {
    local -r line=$1
    local -r file=$2
    if [[ $(grep -c "${line}" ${file}) == 0 ]]; then
	echo "${line}" >>${file}
    fi
}

function replace_or_append {
    local -r pattern=$1
    local -r line=$2
    local -r file=$3
    sed -i -E '/'"${pattern}"'/ s/.*/'"${line}"'/w /tmp/changelog.txt' ${file}
    if [[ ! -s /tmp/changelog.txt ]]; then
	echo "${line}" >>${file}
    fi
}

function replace_or_insert_before {
    local -r pattern=$1
    local -r line=$2
    local -r before=$3
    local -r file=$4
    sed -i -E '/'"${pattern}"'/ s/.*/'"${line}"'/w /tmp/changelog.txt' ${file}
    if [[ ! -s /tmp/changelog.txt ]]; then
	cp ${file} ${file}.bak
	awk '/'"${before}"'/ {print "'"${line}"'"}1' ${file}.bak >${file}
	rm ${file}.bak
    fi
}

function replace_or_insert_after {
    local -r pattern=$1
    local -r line=$2
    local -r after=$3
    local -r file=$4
    sed -i -E '/'"${pattern}"'/ s/.*/'"${line}"'/w /tmp/changelog.txt' ${file}
    if [[ ! -s /tmp/changelog.txt ]]; then
	cp ${file} ${file}.bak
	awk '/'"${after}"'/ {print; print "'"${line}"'"; next}1' ${file}.bak >${file}
	rm ${file}.bak
    fi
}

# Check for GRUB boot password
# Set user and password in GRUB configuration
# Password hash generated with grub-mkpasswd-pbkdf2, password: root
# TODO This is currently disabled as it interferes with the reboot in set_kernel_cmdline.sh
# cat <<END >>/etc/grub.d/00_header
# cat <<EOF
# set superusers="root"
# password_pbkdf2 root grub.pbkdf2.sha512.10000.E4F52CBE09DFC3C338A314E9EDC8AA682BB2832A35FF2FF9E1D12D30EB3D58E9DDE023F88B8A82CD7BF5FC8138500CD0E67174EBA6EFACF98635A693C5AD4BB9.BB41DC42C8E2C68723B94F14F5F1E43845054A7D443C80F074E9B41C44927FEA2832B0E23C83E6B7C5E1D740B67756FA3093DA9A99B2E461A20F4831BBB289AF
# EOF
# END
# update-grub

# Check password hashing methods
# Check /etc PAM and configure algorithm rounds
sed -i -E 's/^(password\s+.*sha512)$/\1 rounds=10000/' /etc/pam.d/common-password
echo "Passwords in /etc/shadow must be encrypted with new values"

# Check group password hashing rounds
# Configure minimum encryption algorithm rounds in /etc/login.defs
replace_or_insert_after '^\s*SHA_CRYPT_MIN_ROUNDS\s+' 'SHA_CRYPT_MIN_ROUNDS 10000' '^#\s+SHA_CRYPT_MIN_ROUNDS' /etc/login.defs
# Configure maximum encryption algorithm rounds in /etc/login.defs
replace_or_insert_after '^\s*SHA_CRYPT_MAX_ROUNDS\s+' 'SHA_CRYPT_MAX_ROUNDS 10000' '^#\s+SHA_CRYPT_MAX_ROUNDS' /etc/login.defs

# Checking user password aging
# Set PASS_MAX_DAYS option in /etc/login.defs
# PASS_MAX_DAYS of 99999 is considered unconfigued by lynis
replace_or_insert_before '^\s*PASS_MAX_DAYS\s+' 'PASS_MAX_DAYS 99000' '^PASS_MIN_DAYS' /etc/login.defs

# Default umask values
# Set default umask in /etc/login.defs to more strict
replace_or_append '^\s*UMASK\s+' 'UMASK 027' /etc/login.defs

# Check for presence of USBGuard
# Ensure USBGuard is installed
apt-get -y install usbguard
# TODO USB hubs and HID device must be enabled for BMC Console Redirection
# Authorize USB hubs in USBGuard daemon
append 'allow with-interface equals { 09:00:\* }' /etc/usbguard/rules.conf
# Authorize multi-function Human Interface Devices
append 'allow with-interface equals { 03:\*:\* 03:\*:\* }' /etc/usbguard/rules.conf
# Set PresentControllerPolicy to apply-policy in USBGuard daemon
sed -i -E 's/^PresentControllerPolicy\s*=\s*keep/PresentControllerPolicy=apply-policy/' /etc/usbguard/usbguard-daemon.conf
chmod 0600 /etc/usbguard/rules.conf
systemctl restart usbguard

# Checking for debsums utility
# Install debsums utility
apt-get -y install debsums

# Check SSH specific defined options
# Disable AllowTcpForwarding
replace_or_append '^\s*AllowTcpForwarding\s+' 'AllowTcpForwarding no' /etc/ssh/sshd_config
# Set ClientAliveCountMax to 2
replace_or_append '^\s*ClientAliveCountMax\s+' 'ClientAliveCountMax 2' /etc/ssh/sshd_config
# Set MaxAuthTries to 3
replace_or_append '^\s*MaxAuthTries\s+' 'MaxAuthTries 3' /etc/ssh/sshd_config
# Set MaxSessions to 2
# TODO MaxSessions of 2 prevents lynis from running under bluval
replace_or_append '^\s*MaxSessions\s+' 'MaxSessions 10' /etc/ssh/sshd_config
# Set server Port to 2222
# TODO lynis, etc. robot files need to be updated to handle a different port
replace_or_append '^\s*Port\s+' 'Port 22' /etc/ssh/sshd_config
# Set client Port to 2222
# TODO lynis, etc. robot files need to be updated to handle a different port
replace_or_append '^\s*Port\s+' '    Port 22' /etc/ssh/ssh_config
# Disable TCPKeepAlive
replace_or_append '^\s*TCPKeepAlive\s+' 'TCPKeepAlive no' /etc/ssh/sshd_config
# Restrict SSH to administrators
replace_or_append '^\s*AllowGroups\s+' 'AllowGroups root sudo' /etc/ssh/sshd_config
# Restart SSH
systemctl restart ssh

# Disabling Apport is necessary to prevent it from overriding
# fs.suid_dumpable in sysctl conf below
replace_or_append '^enabled=' 'enabled=0' /etc/default/apport

# The fs.protected_fifos setting below in 99-zzz-icn.conf does not
# stick on reboot.  The setting in /usr/lib takes precendence, but per
# the sysctl.d manpage, a file with the same name in /etc will
# override /usr/lib.
#
# Reference:
# https://groups.google.com/g/linux.debian.bugs.dist/c/cYMr7EXCcWY?pli=1
sed -e 's/fs.protected_fifos = .*/fs.protected_fifos = 2/' /usr/lib/sysctl.d/protect-links.conf > /etc/sysctl.d/protect-links.conf

# Check sysctl key pairs in scan profile
cat <<EOF >/etc/sysctl.d/99-zzz-icn.conf
dev.tty.ldisc_autoload = 0
fs.protected_fifos = 2
fs.suid_dumpable = 0
kernel.core_uses_pid = 1
kernel.dmesg_restrict = 1
kernel.kptr_restrict = 2
# TODO module loading required by accelerator drivers
# kernel.modules_disabled = 1
kernel.sysrq = 0
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_harden = 2
net.ipv4.conf.all.accept_redirects = 0
# TODO forwarding required by k8s
# net.ipv4.conf.all.forwarding = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.default.log_martians = 1
net.ipv6.conf.all.accept_redirects = 0
net.ipv6.conf.default.accept_redirects = 0
EOF
sysctl --system

# Check compiler permissions
# Uninstall compilers
apt-get -y remove gcc binutils
