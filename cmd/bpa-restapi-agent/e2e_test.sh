#!/bin/bash

ICN_DIR=$(dirname "$(dirname "$PWD")")

source "$ICN_DIR/env/lib/common.sh"

#create sample image
if true ; then
    cat <<- EOF > /tmp/sample_image
    This is a dummy file for testing.
EOF
fi

IMAGE_SIZE=$(ls -al /tmp/sample_image | awk '{print $5}')

if true ; then
    cat <<- EOF > /tmp/sample.json
    {
        "owner":  "alpha",
        "cluster_name": "beta",
        "type": "container",
        "image_name": "qwerty123",
        "image_length": $IMAGE_SIZE,
        "image_offset": 0,
        "upload_complete":  false,
        "description": {
        "image_records":  [
            {
                "image_record_name": "iuysdi1234",
                "repo": "icn",
                "tag":  "2"
            }
            ]
        }
    }
EOF
fi

sleep 15

kubectl get pods --all-namespaces

POD=$(kubectl get pods | grep bpa-api-deployment | awk '{print $1}')

kubectl describe pods $POD

echo "============"

kubectl logs $POD bpa-ap1

echo "============="

kubectl logs $POD mongo

echo "==========="

kubectl logs $POD minio

ls -al /tmp

#Get CLusterIP
IP=$(kubectl get services | grep bpa-api-service | awk '{print $3}')

call_api -i -F "metadata=</tmp/sample.json;type=application/json" -F \
file=@/tmp/sample.json -X POST \
http://$IP:9015/v1/baremetalcluster/alpha/beta/container_images

call_api -i -X GET \
http://$IP:9015/v1/baremetalcluster/alpha/beta/container_images/qwerty123

call_api --request PATCH --data-binary "@/tmp/sample_image" \
http://$IP:9015/v1/baremetalcluster/alpha/beta/container_images/qwerty123 \
--header "Upload-Offset: 0" --header "Expect:" -i

call_api -i -X DELETE \
http://$IP:9015/v1/baremetalcluster/alpha/beta/container_images/qwerty123
