.PHONY: build

build:
	go build -o build/_output/bin/bpa-restapi-agent main.go

docker:	
	docker build -t akraino.org/icn/bpa-restapi-agent:latest . -f build/Dockerfile	

deploy: docker
	./bpa_api_install.sh

unit_test: go_install
	go test ./internal/app

go_install:
	./install_go.sh

e2e_test: deploy
	./e2e_test.sh

clean:
	./bpa_api_uninstall.sh
