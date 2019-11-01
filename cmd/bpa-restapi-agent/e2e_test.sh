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

cur_status=""

while [[ $cur_status != "Running" ]]; do

    cur_status=$(kubectl get pods | grep bpa-api-deployment | awk '{print $3}')
    if [[ $cur_status != "Running" ]]; then
        echo "$(date +%H:%M:%S) - BPA-RESTful-API Pod status: $cur_status"
    else
        break

    fi
    if [[ $cur_status == "Err"* ]]; then
        exit 1
    fi
    sleep 10
done


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
