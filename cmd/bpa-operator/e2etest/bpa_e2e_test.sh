#!/bin/bash

#Install required software
cp fake_dhcp_lease /opt/icn/dhcp/dhcpd.leases
kubectl apply -f bmh-bpa-test.yaml
cat /root/.ssh/id_rsa.pub > vm_authorized_keys
vagrant up
sleep 6
kubectl apply -f e2e_test_provisioning_cr.yaml
