#!/bin/bash
set -e
set -o errexit
set -o pipefail

echo "[ICN] Uninstalling EMCO k8s"
cd k8s/kud/hosting_providers/vagrant
ansible-playbook -i inventory/hosts.ini /opt/kubespray-2.14.1/reset.yml -e container_manager=containerd -e etcd_deployment_type=host -e kubelet_cgroup_driver=cgroupfs -e "{'download_localhost': false}" -e "{'download_run_once': false}" --become --become-user=root -e reset_confirmation=yes

echo "[ICN] Purging Docker fully"
cat << EOF | tee purge-docker.yml
---
- hosts: all
  gather_facts: True
  tasks:
    - name: reset | remove all docker images
      shell: "/usr/bin/docker image ls -a -q | xargs -r /usr/bin/docker rmi -f"
      retries: 2
      delay: 5
      tags:
        - docker
    - name: reset | remove docker itself
      shell: "apt-get purge docker-* -y --allow-change-held-packages"
      retries: 2
      delay: 30
      tags:
        - docker
EOF
ansible-playbook -i inventory/hosts.ini purge-docker.yml --become --become-user=root
