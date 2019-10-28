.PHONY: build
build:
	go build -o build/_output/bin/bpa-operator cmd/manager/main.go

docker:
	docker build -t akraino.org/icn/bpa-operator:latest . -f build/Dockerfile

.PHONY: deploy
deploy:
	kubectl apply -f deploy/service_account.yaml
	kubectl apply -f deploy/role.yaml
	kubectl apply -f deploy/role_binding.yaml
	kubectl apply -f deploy/crds/provisioning-crd/bpa_v1alpha1_provisioning_crd.yaml
	kubectl apply -f deploy/crds/software-crd/bpa_v1alpha1_software_crd.yaml
	kubectl apply -f deploy/operator.yaml

.PHONY: delete
delete:
	kubectl delete -f deploy/service_account.yaml
	kubectl delete -f deploy/role.yaml
	kubectl delete -f deploy/role_binding.yaml
	kubectl delete -f deploy/crds/provisioning-crd/bpa_v1alpha1_provisioning_crd.yaml
	kubectl delete -f deploy/crds/software-crd/bpa_v1alpha1_software_crd.yaml
	kubectl delete -f deploy/operator.yaml

.PHONY: e2etest
e2etest:
	cd e2etest && ./bpa_e2e_test.sh

.PHONY: e2evmtest
e2evmtest:
        cd e2etest && ./bpa_e2e_vm_test.sh
