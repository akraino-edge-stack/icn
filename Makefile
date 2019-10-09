SHELL:=/bin/bash
BMDIR:=$(CURDIR)/env/metal3
METAL3DIR:=$(CURDIR)/deploy/metal3/scripts
BPA_OPERATOR:=$(CURDIR)/cmd/bpa-operator/
KUD_PATH:=$(CURDIR)/deploy/kud
BPA_REST_API:=$(CURDIR)/cmd/bpa-restapi-agent

all: bm_install

bm_preinstall:
	pushd $(BMDIR) && ./01_install_package.sh && ./02_configure.sh && ./03_launch_prereq.sh && popd

bm_install:
	pushd $(METAL3DIR) && ./metal3.sh && popd 

bm_all: bm_preinstall bm_install

kud_download:
	pushd $(KUD_PATH) && ./kud_launch.sh && popd

bpa_op_install: kud_download
	pushd $(BPA_OPERATOR) && ./bpa_operator_launch.sh && popd

bpa_op_all: bm_all bpa_op_install

bpa_rest_api_install:
	pushd $(BPA_REST_API) && make docker && make deploy && popd

bpa_rest_api_e2e:
	pushd $(BPA_REST_API) && make e2e_test && popd

.PHONY: all bm_preinstall bm_install
