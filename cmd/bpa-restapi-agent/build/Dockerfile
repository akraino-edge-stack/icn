FROM golang:1.13 AS builder
RUN mkdir /bpa-restapi-agent
ADD . /bpa-restapi-agent
WORKDIR /bpa-restapi-agent

RUN make build

FROM golang:1.13

COPY --from=builder /bpa-restapi-agent/build/_output/bin/bpa-restapi-agent /bpa-restapi-agent

ENTRYPOINT ["/bpa-restapi-agent"]
