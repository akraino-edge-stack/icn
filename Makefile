SHELL:=/bin/bash
BMDIR:=$(CURDIR)/env/metal3
METAL3DIR:=$(CURDIR)/deploy/metal3/scripts
BPA_OPERATOR:=$(CURDIR)/cmd/bpa-operator/
KUD_PATH:=$(CURDIR)/deploy/kud
BPA_E2E_SETUP:=https://raw.githubusercontent.com/onap/multicloud-k8s/master/kud/hosting_providers/vagrant/setup.sh

all: bm_install

bm_preinstall:
	pushd $(BMDIR) && ./01_install_package.sh && ./02_configure.sh && ./03_launch_prereq.sh && popd

bm_install:
	pushd $(METAL3DIR) && ./metal3.sh && popd

bm_all: bm_preinstall bm_install

kud_download:
	pushd $(KUD_PATH) && ./kud_launch.sh && popd

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


.PHONY: all bm_preinstall bm_install
