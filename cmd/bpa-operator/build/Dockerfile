FROM golang:1.12 AS builder
WORKDIR /go/src/github.com/bpa-operator
COPY . .
RUN make build

FROM golang:1.12

COPY --from=builder /go/src/github.com/bpa-operator/build/_output/bin/bpa-operator /
