set -e
export DEBIAN_FRONTEND=noninteractive
apt-get update
pip install ansible
ansible-galaxy install geerlingguy.jenkins,3.7.0 --roles-path /etc/ansible/roles
