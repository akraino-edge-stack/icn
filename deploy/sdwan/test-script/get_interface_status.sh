echo 'exec: wget --header="Cookie:sysauth='$1'" http://10.233.64.171/cgi-bin/luci/admin/status/mwan/interface_status'
wget --header="Cookie:sysauth=$1" http://$2/cgi-bin/luci/admin/status/mwan/interface_status
