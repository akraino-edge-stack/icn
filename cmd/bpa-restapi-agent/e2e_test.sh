#!/bin/bash

#Create temporary sample json
SAMPLE_JSON=$(mktemp /tmp/sample.json

#Get CLusterIP
#CLUSTER_IP=$(kubectl ...)

#POST=$(curl -i -F "metadata=<sample.json;type=application/json" -F file=@$SAMPLE_JSON -X POST http://CLUSTER_IP:9015/v1/baremetalcluster/alpha/beta/binary_images)

#compare expected and actual response
#echo $POST


