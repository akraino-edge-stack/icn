
# # The name of the executable (default is current directory name)
# TARGET := $(shell echo $${PWD\#\#*/})
# .DEFAULT_GOAL: $(TARGET)
#
# # These will be provided to the target
# VERSION := 1.0.0
# BUILD := `git rev-parse HEAD`
#
# # Use linker flags to provide version/build settings to the target
# LDFLAGS=-ldflags "-X=main.Version=$(VERSION) -X=main.Build=$(BUILD)"
#
# # go source files, ignore vendor directory
# SRC = $(shell find . -type f -name '*.go' -not -path "./vendor/*")
#
# .PHONY: all build
#
# all: build
#
# $(TARGET): $(SRC)
# 	@go build $(LDFLAGS) -o $(TARGET)
#
# build: $(TARGET)
# 	@true

.PHONY: build

build:
	go build -mod=vendor -o build/_output/bin/bpa-restapi-agent main.go

docker:	untar
	docker build -t akraino.org/icn/bpa-restapi-agent:latest . -f build/Dockerfile

untar:
	tar -xzvf vendor.tar.gz

deploy: docker
	bpa_api_install.sh

unit_test:
	go test ./... -v

e2e_test: deploy
	./e2e_test.sh
