export DEBIAN_FRONTEND=noninteractive
apt update
apt install -y ansible
ansible-galaxy install geerlingguy.jenkins,3.7.0 --roles-path /etc/ansible/roles
