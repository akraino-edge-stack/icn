.PHONY: build
build:
	go build -o build/_output/bin/bpa-operator cmd/manager/main.go

docker:
	docker build --rm -t akraino.org/icn/bpa-operator:latest . -f build/Dockerfile
	git clone https://github.com/onap/multicloud-k8s.git
	cd multicloud-k8s && \
	docker build  --rm \
         	--build-arg http_proxy=${http_proxy} \
         	--build-arg HTTP_PROXY=${HTTP_PROXY} \
         	--build-arg https_proxy=${https_proxy} \
         	--build-arg HTTPS_PROXY=${HTTPS_PROXY} \
         	--build-arg no_proxy=${no_proxy} \
         	--build-arg NO_PROXY=${NO_PROXY} \
         	-t github.com/onap/multicloud-k8s:latest . -f kud/build/Dockerfile
	rm -rf multicloud-k8s


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

.PHONY: unit_test
unit_test:
	go test ./pkg/controller/provisioning/

.PHONY: e2etest
e2etest:
	./bpa_verifier.sh

.PHONY: e2evmtest
e2evmtest:
	cd e2etest && ./bpa_e2e_vm_test.sh
