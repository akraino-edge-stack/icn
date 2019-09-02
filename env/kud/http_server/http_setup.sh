#!/bin/bash

set -ex

sudo swapoff -a
sudo apt-get update
sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
sudo apt-get update
sudo apt-get install -y docker-ce
sudo apt-get install apache2 -y
sudo ufw allow 'Apache'
sudo mkdir /var/www/icn
sudo chown -R stack:stack /var/www/icn
sudo chmod -R 755 /var/www/icn
sudo cp ./icn.conf /etc/apache2/sites-available/icn.conf
sudo cp -rf ./files/  /var/www/icn/
sudo cp ./index.html /var/www/icn/index.html
sudo a2ensite icn.conf
sudo a2dissite 000-default.conf
apache2ctl configtest
sudo systemctl restart apache2
wget http://localhost/files/yui.tar.gz
