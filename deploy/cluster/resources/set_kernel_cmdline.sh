#!/usr/bin/env bash
# The "intel_iommu=on iommu=pt" kernel command line is necessary
# for QAT support
# TODO Add check for existence of QAT hardware?
set -eux -o pipefail
grub_file=${1:-"/etc/default/grub"}
kernel_parameters="intel_iommu=on iommu=pt"
sed -i~ "/^GRUB_CMDLINE_LINUX=/{h;s/\(=\".*\)\"/\1 ${kernel_parameters}\"/};\${x;/^$/{s//GRUB_CMDLINE_LINUX=\"${kernel_parameters}\"/;H};x}" "$grub_file"
update-grub
reboot
