.PHONY: build
build:
	go build -o build/_output/bin/bpa-operator cmd/manager/main.go

docker:
	docker build --rm -t akraino.org/icn/bpa-operator:latest . -f build/Dockerfile
	git clone https://github.com/rkamudhan/multicloud-k8s.git
	cd multicloud-k8s && \
	docker build  --network=host --rm \
         	--build-arg http_proxy=${http_proxy} \
         	--build-arg HTTP_PROXY=${HTTP_PROXY} \
         	--build-arg https_proxy=${https_proxy} \
         	--build-arg HTTPS_PROXY=${HTTPS_PROXY} \
         	--build-arg no_proxy=${no_proxy} \
         	--build-arg NO_PROXY=${NO_PROXY} \
         	-t github.com/onap/multicloud-k8s:latest . -f kud/build/Dockerfile
	rm -rf multicloud-k8s

docker_bmh_e2e:
	docker build --rm -t akraino.org/icn/bpa-operator:latest . -f build/Dockerfile
	git clone https://github.com/rkamudhan/multicloud-k8s.git
	cd multicloud-k8s && \
        docker build  --network=host --rm \
        	--build-arg http_proxy=${http_proxy} \
        	--build-arg HTTP_PROXY=${HTTP_PROXY} \
        	--build-arg https_proxy=${https_proxy} \
        	--build-arg HTTPS_PROXY=${HTTPS_PROXY} \
        	--build-arg no_proxy=${no_proxy} \
        	--build-arg NO_PROXY=${NO_PROXY} \
        	--build-arg KUD_ENABLE_TESTS=true \
        	--build-arg KUD_PLUGIN_ENABLED=true \
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
	kubectl create secret generic ssh-key-secret --from-file=id_rsa=/root/.ssh/id_rsa --from-file=id_rsa.pub=/root/.ssh/id_rsa.pub

.PHONY: delete
delete:
	kubectl delete -f deploy/service_account.yaml
	kubectl delete -f deploy/role.yaml
	kubectl delete -f deploy/role_binding.yaml
	kubectl delete -f deploy/crds/provisioning-crd/bpa_v1alpha1_provisioning_crd.yaml
	kubectl delete -f deploy/crds/software-crd/bpa_v1alpha1_software_crd.yaml
	kubectl delete -f deploy/operator.yaml
	kubectl delete secret ssh-key-secret

.PHONY: unit_test
unit_test:
	go test ./pkg/controller/provisioning/

.PHONY: e2etest_vm
e2etest_vm:
	./e2etest/bpa_vm_verifier.sh

.PHONY: e2etest_bmh
e2etest_bmh:
	./e2etest/bpa_bmh_verifier.sh

.PHONY: e2etest_virtletvm
e2etest_virtletvm:
	cd e2etest && ./bpa_virtletvm_verifier.sh
