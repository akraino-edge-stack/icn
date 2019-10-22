echo 'exec: wget -S --post-data "luci_username=root&luci_password=" http://10.233.64.171/cgi-bin/luci/'
wget -S --post-data "luci_username=root&luci_password=" http://$1/cgi-bin/luci/
