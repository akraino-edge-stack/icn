#!/usr/bin/env bash
#
# Copyright 2019 Intel Corporation and Smart-Edge.com, Inc. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

id -u 1>/dev/null
if [[ $? -ne 0 ]]; then
  echo "ERROR: Script requires root permissions"
  exit 1
fi

if [ ${0##*/} == ${BASH_SOURCE[0]##*/} ]; then
    echo "ERROR: This script cannot be executed directly"
    exit 1
fi

command -v ansible-playbook 1>/dev/null
if [[ $? -ne 0 ]]; then
  echo "Ansible not installed..."

  echo "Add ansible repository"
  apt-add-repository -y ppa:ansible/ansible

  echo "Installing ansible..."
  apt-get install -y ansible
  if [[ $? -ne 0 ]]; then
    echo "ERROR: Could not install Ansible"
    exit 1
  fi
  echo "Ansible successfully instaled"
fi
