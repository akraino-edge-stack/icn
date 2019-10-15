#!/bin/bash

kubectl delete -f e2e_test_provisioning_cr.yaml
kubectl delete -f bmh-bpa-test.yaml
kubectl delete job kud-cluster-test
vagrant destroy -f
