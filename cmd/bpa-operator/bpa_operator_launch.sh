#!/bin/bash

#Get Go ENV variables
eval "$(go env)"

#Copy bpa operator directory to the right path
echo $GOPATH
mkdir -p $GOPATH/github.com/ && cp -r $PWD/cmd/bpa-operator $GOPATH/github.com/bpa-operator
pushd $GOPATH/github.com/bpa-operator
operator-sdk up local --kubeconfig $HOME/.kube/config
popd
