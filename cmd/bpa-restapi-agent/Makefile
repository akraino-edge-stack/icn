.PHONY: build

build:	untar
	go build -mod=vendor -o build/_output/bin/bpa-restapi-agent main.go

docker:	
	docker build -t akraino.org/icn/bpa-restapi-agent:latest . -f build/Dockerfile

untar:
	tar -xzvf vendor.tar.gz

deploy: docker
	./bpa_api_install.sh

test:	go_install
	go test ./... -v

go_install:
	install_go.sh

e2e_test: deploy
	./e2e_test.sh
