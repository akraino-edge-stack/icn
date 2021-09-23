#! /bin/bash

NS=(default prioslice)
cpdp=${1:-"cplane"}


if [ $cpdp == "cplane" ]; then
	NF_0=(pcf nssf ausf udm udr nrf mongodb)
	NF_1=(pcf ausf udm udr nrf)
elif [ $cpdp == "dplane" ]; then
	NF_0=(smf upf amf)
	NF_1=(smf upf)
else
	echo "Unknown Option $cpdp"
	echo "Allowed options are: cplane dplane"
	exit 2
fi

for i in ${NF_1[@]}
do
	helm uninstall free5g-$i-${NS[1]} --namespace ${NS[1]}
	sleep 5
done

for i in ${NF_0[@]}
do
	helm uninstall free5g-$i-${NS[0]} --namespace ${NS[0]}
	sleep 5
done
kubectl get pods -o wide -n ${NS[1]}
kubectl get pods -o wide -n ${NS[0]}
