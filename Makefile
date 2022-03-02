SHELL:=/bin/bash

help:
	@echo "  Targets:"
	@echo "  jump_server      -- install jump server into this machine"
	@echo "  unit             -- run the unit tests"
	@echo "  verifier         -- run verifier tests for CI & CD logs"
	@echo "  vm_cluster       -- deploy VM compute cluster"
	@echo "  pod11_cluster    -- deploy pod11 compute cluster"
	@echo "  help             -- this help output"

install: jump_server

# The jump server

jump_server: management_cluster \
	tools \
	ironic_bridge \
	controllers

jump_server_clean: controllers_clean \
	ironic_bridge_clean \
	management_cluster_clean

# The jump server requires a K8s cluster to install into

management_cluster:
	source user_config.sh && \
	./deploy/kud/kud_bm_launch.sh minimal

management_cluster_clean:
	./deploy/kud/kud_bm_launch.sh reset

# Tools used during the installation of jump server components

tools: kustomize \
	clusterctl \
	flux_cli \
	sops \
	emcoctl

kustomize:
	./deploy/kustomize/kustomize.sh deploy

clusterctl:
	./deploy/clusterctl/clusterctl.sh deploy

flux_cli:
	./deploy/flux-cli/flux-cli.sh deploy

sops:
	./deploy/sops/sops.sh deploy

emcoctl: golang
	./deploy/emcoctl/emcoctl.sh deploy

golang:
	./deploy/golang/golang.sh deploy

kubectl:
	./deploy/kubectl/kubectl.sh deploy

yq:
	./deploy/yq.sh deploy

# Provisioning network configuration in the jump server

ironic_bridge:
	source user_config.sh && env && \
	./deploy/ironic/ironic.sh deploy-bridge

ironic_bridge_clean:
	source user_config.sh && \
	./deploy/ironic/ironic.sh clean-bridge

# Jump server components

controllers: ironic \
	cert_manager \
	baremetal_operator \
	cluster_api \
	flux

controllers_clean: flux_clean \
	cluster_api_clean \
	baremetal_operator_clean \
	cert_manager_clean \
	ironic_clean

baremetal_operator:
	./deploy/baremetal-operator/baremetal-operator.sh deploy

baremetal_operator_clean:
	./deploy/baremetal-operator/baremetal-operator.sh clean

ironic:
	source user_config.sh && \
	./deploy/ironic/ironic.sh deploy

ironic_clean:
	source user_config.sh && \
	./deploy/ironic/ironic.sh clean

cert_manager:
	./deploy/cert-manager/cert-manager.sh deploy

cert_manager_clean:
	./deploy/cert-manager/cert-manager.sh clean

cluster_api:
	./deploy/cluster-api/cluster-api.sh deploy

cluster_api_clean:
	./deploy/cluster-api/cluster-api.sh clean

flux:
	./deploy/flux/flux.sh deploy

flux_clean:
	./deploy/flux/flux.sh clean

# Example compute clusters

pod11_cluster:
	./deploy/site/pod11/pod11.sh deploy
	./deploy/site/pod11/pod11.sh wait
	./deploy/kata/kata.sh test
	./deploy/addons/addons.sh test

pod11_cluster_clean:
	./deploy/site/pod11/pod11.sh clean
	./deploy/site/pod11/pod11.sh wait-clean

vm_cluster:
	./deploy/site/vm/vm.sh deploy
	./deploy/site/vm/vm.sh wait
	./deploy/kata/kata.sh test
	./deploy/addons/addons.sh test

vm_cluster_clean:
	./deploy/site/vm/vm.sh clean
	./deploy/site/vm/vm.sh wait-clean

# Test targets

unit: bashate

bashate:
	bashate -i E006,E003,E002,E010,E011,E042,E043 `find . -type f -not -path './ci/jjb/shell/*' -not -path './build/*' -name "*.sh"`

verifier: vm_verifier

vm_verifier: jump_server \
	vm_cluster \
	vm_cluster_clean \
	jump_server_clean

bm_verifier: jump_server \
	pod11_cluster \
	pod11_cluster_clean \
	jump_server_clean

SDWAN_VERIFIER_PATH:=$(CURDIR)/sdwan/test
sdwan_verifier:
	pushd $(SDWAN_VERIFIER_PATH) && bash sdwan_verifier.sh && popd

# Development targets
source: flux_cli kubectl kustomize yq
	./deploy/baremetal-operator/baremetal-operator.sh build-source
	./deploy/cdi-operator/cdi-operator.sh build-source
	./deploy/cdi/cdi.sh build-source
	./deploy/cert-manager/cert-manager.sh build-source
	./deploy/cluster/cluster.sh build-source
	./deploy/cpu-manager/cpu-manager.sh build-source
	./deploy/ironic/ironic.sh build-source
	./deploy/kata/kata.sh build-source
	./deploy/kubevirt-operator/kubevirt-operator.sh build-source
	./deploy/kubevirt/kubevirt.sh build-source
	./deploy/multus-cni/multus-cni.sh build-source
	./deploy/nodus/nodus.sh build-source
	./deploy/qat-plugin/qat-plugin.sh build-source
