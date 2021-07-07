set -e
export DEBIAN_FRONTEND=noninteractive
apt update
apt-get install -y python3-pip
pip3 install ansible
ansible-galaxy install geerlingguy.jenkins,3.7.0 --roles-path /etc/ansible/roles
