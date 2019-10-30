SHELL:=/bin/bash
ENV:=$(CURDIR)/env
BMDIR:=$(CURDIR)/env/metal3
METAL3DIR:=$(CURDIR)/deploy/metal3/scripts
METAL3VMDIR:=$(CURDIR)/deploy/metal3-vm
BPA_OPERATOR:=$(CURDIR)/cmd/bpa-operator/
KUD_PATH:=$(CURDIR)/deploy/kud
BPA_E2E_SETUP:=https://raw.githubusercontent.com/onap/multicloud-k8s/master/kud/hosting_providers/vagrant/setup.sh

help:
	@echo "  Targets:"
	@echo "  test             -- run unit tests"
	@echo "  installer        -- run icn installer"
	@echo "  verifier         -- run verifier tests for CI & CD logs"
	@echo "  unit             -- run the unit tests"
	@echo "  help             -- this help output"

all: bm_install

bm_preinstall:
	pushd $(BMDIR) && ./01_install_package.sh && ./02_configure.sh && ./03_launch_prereq.sh && popd

bm_install:
	pushd $(METAL3DIR) && ./metal3.sh && popd

bm_all: bm_preinstall bm_install

kud_bm_deploy_mini:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh minimal && popd

kud_bm_deploy:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh all && popd

metal3_prerequisite:
	pushd $(METAL3VMDIR) && make bmh_install && popd

metal3_vm:
	pushd $(METAL3VMDIR) && make bmh && popd

bpa_op_install:
	pushd $(BPA_OPERATOR) && make docker && make deploy && popd

bpa_op_delete:
	pushd $(BPA_OPERATOR) && make delete && popd

bpa_op_e2e_preinstall:
	wget $(BPA_E2E_SETUP) && bash setup.sh -p libvirt

bpa_op_e2e:
	pushd $(BPA_OPERATOR) && make e2etest && popd

bpa_op_verifier: bpa_op_install bpa_op_e2e	

bpa_op_all: bm_all bpa_op_install

bashate:
	bashate -i E006,E003,E002,E010,E042,E043 `find . -type f -not -path './cmd/bpa-operator/vendor/*' -name *.sh`

prerequisite:
	pushd $(ENV) && ./cd_package_installer.sh && popd

verify_all: prerequisite \
	metal3_prerequisite \
	kud_bm_deploy_mini \
	metal3_vm

verifier: verify_all

verify_nestedk8s: prerequisite \
	kud_bm_deploy

.PHONY: all bm_preinstall bm_install bashate
