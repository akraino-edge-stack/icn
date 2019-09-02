#!/bin/bash

set -ex

sudo apt-get update
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
