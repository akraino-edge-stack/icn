SHELL:=/bin/bash
ENV:=$(CURDIR)/env
BMDIR:=$(CURDIR)/env/metal3
KUD_PATH:=$(CURDIR)/deploy/kud
SDWAN_VERIFIER_PATH:=$(CURDIR)/sdwan/test
BOOTLOADER_ENV:=$(CURDIR)/env/ubuntu/bootloader-env

help:
	@echo "  Targets:"
	@echo "  test             -- run unit tests"
	@echo "  jump_server      -- install jump server into this machine"
	@echo "  cluster          -- provision cluster(s)"
	@echo "  verifier         -- run verifier tests for CI & CD logs"
	@echo "  unit             -- run the unit tests"
	@echo "  help             -- this help output"

install: jump_server

jump_server: package_prerequisite \
	kud_bm_deploy_mini \
	bmo_install \
	capi_install \
	flux_install

clean_jump_server: bmo_clean_host \
	kud_bm_reset \
	clean_packages

package_prerequisite:
	 pushd $(BMDIR) && ./01_install_package.sh && popd

bmo_clean:
	./deploy/baremetal-operator/baremetal-operator.sh clean

bmo_clean_host:
	pushd $(BMDIR) && ./06_host_cleanup.sh && popd

clean_packages:
	pushd $(BOOTLOADER_ENV) && \
	./02_clean_bootloader_package_req.sh --only-packages && popd

clean_bm_packages:
	pushd $(BOOTLOADER_ENV) && \
        ./02_clean_bootloader_package_req.sh --bm-cleanall && popd

bmo_install:
	source user_config.sh && env && \
	pushd $(BMDIR) && ./02_configure.sh && popd && \
	./deploy/ironic/ironic.sh deploy && \
	./deploy/cert-manager/cert-manager.sh deploy && \
	./deploy/baremetal-operator/baremetal-operator.sh deploy

kud_bm_deploy_mini:
	source user_config.sh && \
	pushd $(KUD_PATH) && ./kud_bm_launch.sh minimal v1 && popd

kud_bm_deploy:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh all v2 && popd

kud_bm_deploy_e2e:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh bm v2 && popd

kud_bm_reset:
	pushd $(KUD_PATH) && ./kud_bm_launch.sh reset v1 && popd

sdwan_verifier:
	pushd $(SDWAN_VERIFIER_PATH) && bash sdwan_verifier.sh && popd

capi_install:
	./deploy/cluster-api/cluster-api.sh deploy

flux_install:
	./deploy/flux/flux.sh deploy

unit: prerequisite \
	bashate

bashate:
	bashate -i E006,E003,E002,E010,E011,E042,E043 `find . -type f -not -path './cmd/bpa-operator/vendor/*' -not -path './ci/jjb/shell/*' -name "*.sh"`

prerequisite:
	pushd $(ENV) && ./cd_package_installer.sh && popd

bm_verifer: jump_server \
	pod11_cluster \
	pod11_clean_cluster \
	clean_jump_server

pod11_cluster:
	./deploy/site/pod11/pod11.sh deploy
	./deploy/site/pod11/pod11.sh wait
	./deploy/kata/kata.sh test
	./deploy/addons/addons.sh test

pod11_clean_cluster:
	./deploy/site/pod11/pod11.sh clean

verifier: vm_verifier

vm_verifier: jump_server \
	vm_cluster \
	vm_clean_cluster \
	clean_jump_server

vm_cluster:
	./deploy/site/vm/vm.sh deploy
	./deploy/site/vm/vm.sh wait
	./deploy/kata/kata.sh test
	./deploy/addons/addons.sh test

vm_clean_cluster:
	./deploy/site/vm/vm.sh clean

bm_verify_nestedk8s: prerequisite \
        kud_bm_deploy_e2e \
        kud_bm_reset \
	clean_bm_packages

kud_bm_verifier: prerequisite \
	kud_bm_deploy_e2e \
	kud_bm_reset \
	clean_bm_packages

.PHONY: all bashate
