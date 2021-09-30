SHELL:=/bin/bash
ENV:=$(CURDIR)/env
BMDIR:=$(CURDIR)/env/metal3
METAL3DIR:=$(CURDIR)/deploy/metal3/scripts
BPA_OPERATOR:=$(CURDIR)/cmd/bpa-operator/
KUD_PATH:=$(CURDIR)/deploy/kud
SDWAN_VERIFIER_PATH:=$(CURDIR)/sdwan/test
BPA_REST_API:=$(CURDIR)/cmd/bpa-restapi-agent
BOOTLOADER_ENV:=$(CURDIR)/env/ubuntu/bootloader-env

help:
	@echo "  Targets:"
	@echo "  test             -- run unit tests"
	@echo "  installer        -- run icn installer"
	@echo "  verifier         -- run verifier tests for CI & CD logs"
	@echo "  unit             -- run the unit tests"
	@echo "  help             -- this help output"

install: package_prerequisite \
	kud_bm_deploy_mini \
	bmh_all \
	bpa_op_install \
	bpa_rest_api_install

package_prerequisite:
	 pushd $(BMDIR) && ./01_install_package.sh && popd

bmh_preinstall:
	source user_config.sh && env && \
	pushd $(BMDIR) && ./02_configure.sh && \
	./03_launch_prereq.sh && popd

bmh_clean:
	pushd $(METAL3DIR) && ./01_metal3.sh deprovision && \
	./03_verify_deprovisioning.sh && ./01_metal3.sh clean && \
        ./01_metal3.sh remove && popd

bmh_clean_host:
	pushd $(BMDIR) && ./06_host_cleanup.sh && popd

clean_packages:
	pushd $(BOOTLOADER_ENV) && \
	./02_clean_bootloader_package_req.sh --only-packages && popd

clean_bm_packages:
	pushd $(BOOTLOADER_ENV) && \
        ./02_clean_bootloader_package_req.sh --bm-cleanall && popd

bmh_install:
	source user_config.sh && env && \
	pushd $(METAL3DIR) && ./01_metal3.sh launch && \
	 ./01_metal3.sh provision && ./02_verify.sh && popd

bmh_all: bmh_preinstall bmh_install

clean_all: bmh_clean \
	bmh_clean_host \
	kud_bm_reset \
	clean_packages

kud_bm_deploy_mini:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh minimal v1 && popd

kud_bm_deploy:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh all v2 && popd

kud_bm_deploy_e2e:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh bm v2 && popd

kud_vm_deploy:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh vm v1 && popd

kud_bm_reset:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh reset v1 && popd

sdwan_verifier:
	pushd $(SDWAN_VERIFIER_PATH) && bash sdwan_verifier.sh && popd

bpa_op_install:
	pushd $(BPA_OPERATOR) && make docker && make deploy && popd

bpa_op_install_e2e:
	pushd $(BPA_OPERATOR) && make docker_e2e && make deploy && popd

bpa_op_delete:
	pushd $(BPA_OPERATOR) && make delete && popd

bpa_op_e2e_bmh:
	pushd $(BPA_OPERATOR) && make e2etest_bmh && popd

bpa_op_e2e_virtletvm:
	pushd $(BPA_OPERATOR) && make e2etest_virtletvm && popd

bpa_op_unit:
	pushd $(BPA_OPERATOR) && make unit_test && popd

bpa_op_bmh_verifier: bpa_op_install_e2e bpa_op_e2e_bmh

bpa_op_virtletvm_verifier: bpa_op_install bpa_op_e2e_virtletvm

bpa_op_all: bm_all bpa_op_install

bpa_rest_api_install:
	pushd $(BPA_REST_API) && make deploy && popd

bpa_rest_api_uninstall:
	pushd $(BPA_REST_API) && make clean && popd

bpa_rest_api_verifier:
	pushd $(BPA_REST_API) && make e2e_test && popd

bpa_rest_api_unit:
	pushd $(BPA_REST_API) && make unit_test && popd

unit: prerequisite \
	bashate \
	bpa_op_unit \
	bpa_rest_api_unit

bashate:
	bashate -i E006,E003,E002,E010,E011,E042,E043 `find . -type f -not -path './cmd/bpa-operator/vendor/*' -not -path './ci/jjb/shell/*' -name "*.sh"`

prerequisite:
	pushd $(ENV) && ./cd_package_installer.sh && popd

bm_verifer: package_prerequisite \
        kud_bm_deploy_mini \
        bmh_all \
	bpa_op_bmh_verifier \
	bpa_rest_api_verifier \
	clean_all

verifier: bm_verifer

verify_nestedk8s: prerequisite \
	kud_vm_deploy \
	bpa_op_virtletvm_verifier \
	kud_bm_reset \
	clean_bm_packages

bm_verify_nestedk8s: prerequisite \
        kud_bm_deploy_e2e \
        kud_bm_reset \
	clean_bm_packages

kud_bm_verifier: prerequisite \
	kud_bm_deploy_e2e \
	kud_bm_reset \
	clean_bm_packages

.PHONY: all bm_preinstall bm_install bashate
