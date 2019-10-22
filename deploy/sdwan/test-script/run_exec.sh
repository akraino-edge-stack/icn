# wget -S --header="Cookie:sysauth=$1" --post-data "command=uci set sample.value='value2'" http://10.233.64.171/cgi-bin/luci/admin/status/mwan/exec_command
#wget -S --header="Cookie:sysauth=$1" --post-data "command=uci set firewall.@rule[1].target='ACCEPT';/etc/init.d/firewall restart" http://$2/cgi-bin/luci/admin/config/command
wget -S --header="Cookie:sysauth=$1" --post-data "command=uci set firewall.@rule[1].target='ACCEPT';fw3 reload" http://$2/cgi-bin/luci/admin/config/command
