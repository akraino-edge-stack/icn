#!/bin/bash

#Get Go ENV variables
eval "$(go env)"

export GO111MODULE=on
go get -d github.com/operator-framework/operator-sdk # This will download the git repository and not install it
pushd $GOPATH/src/github.com/operator-framework/operator-sdk
git checkout master
make tidy
make install
popd

#Copy bpa operator directory to the right path
kubectl create -f $PWD/deploy/crds/bpa_v1alpha1_provisioning_crd.yaml 
echo $GOPATH
mkdir -p $GOPATH/src/github.com/ && cp -r $PWD $GOPATH/src/github.com/bpa-operator
pushd $GOPATH/src/github.com/bpa-operator
operator-sdk up local --kubeconfig $HOME/.kube/config
popd
