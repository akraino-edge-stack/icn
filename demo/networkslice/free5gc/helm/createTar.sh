#! /bin/bash

rm -rf f5gc*.tgz
for i in mongodb nrf udr udm ausf nssf pcf upf amf smf
do
       	tar -czvf f5gc-$i.tgz f5gc-$i
done
ls -l f5gc*.tgz
