### Running the server
To run the server, follow these simple steps:

Integrated Cloud Native (ICN) RESTful API

This is a Golang application providing a RESTful API to interact with and upload image objects.

The API application source files are in the icn/cmd/bpa-restapi-agent directory.

While the database back-end is extensible, this initial release requires mongodb.

Install

Install and start mongodb. For instructions: https://docs.mongodb.com/manual/installation/

git clone "https://gerrit.akraino.org/r/icn"
cd icn/cmd/bpa-restapi-agent

Run the application
go run main.go

Output without a  config file:

2019/08/22 14:08:41 Error loading config file. Using defaults
2019/08/22 14:08:41 Starting Integrated Cloud Native API

RESTful API usage examples

Sample Post Request

curl -i -F "metadata=<jsonfile;type=application/json" -F file=@/home/<username>/<dir>/jsonfile -X POST http://NODE_IP:9015//baremetalcluster/{owner}/{clustername}/<image_type>

#image type can be binary_image, container_image, or os_image

Example requests and responses:

Create image - POST

#Using a json file called sample.json
#image_length in sample.json can be determined with the command
ls -al <image_file>

Request

curl -i -F "metadata=<sample.json;type=application/json" -F file=@/home/enyi/workspace/icn/cmd/bpa-restapi-agent/sample.json -X POST http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images

Response

HTTP/1.1 100 Continue

HTTP/1.1 201 Created
Content-Type: application/json
Date: Thu, 22 Aug 2019 22:56:16 GMT
Content-Length: 239

{"owner":"alpha","cluster_name":"beta","type":"container","image_name":"asdf246","image_offset":0,"image_length":29718177,"upload_complete":false,"description":{"image_records":[{"image_record_name":"iuysdi1234","repo":"icn","tag":"1"}]}}

#this creates a database entry for the image, and an empty file in the file system

List image - GET

curl -i -X GET http://localhost:9015/v1/baremetalcluster/{owner}/{clustername}/<image_type>/{imgname}


example:
#continuing with our container image from above

Request

curl -i -X GET http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246

Response

HTTP/1.1 200 OK
Content-Type: application/json
Date: Thu, 22 Aug 2019 22:57:10 GMT
Content-Length: 239

{"owner":"alpha","cluster_name":"beta","type":"container","image_name":"asdf246","image_offset":0,"image_length":29718177,"upload_complete":false,"description":{"image_records":[{"image_record_name":"iuysdi1234","repo":"icn","tag":"1"}]}}

Upload container image - PATCH
Request

curl --request PATCH --data-binary "@/home/enyi/workspace/icn/cmd/bpa-restapi-agent/sample_image" http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246 --header "Upload-Offset: 0" --header "Expect:" -i


Response

HTTP/1.1 204 No Content
Upload-Offset: 29718177
Date: Thu, 22 Aug 2019 23:19:44 GMT

Check uploaded image - GET

Request

curl -i -X GET http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246

Response

HTTP/1.1 200 OK
Content-Type: application/json
Date: Fri, 23 Aug 2019 17:12:07 GMT
Content-Length: 245

{"owner":"alpha","cluster_name":"beta","type":"container","image_name":"asdf246","image_offset":29718177,"image_length":29718177,"upload_complete":true,"description":{"image_records":[{"image_record_name":"iuysdi1234","repo":"icn","tag":"1"}]}}

#after the upload, the image_offset is now the same as image_length and upload_complete changed to true
#if upload was incomplete

Resumable upload instructions

Resumable upload -PATCH

#this is the current resumable upload mechanism

Request

curl --request PATCH --data-binary "@/home/enyi/workspace/icn/cmd/bpa-restapi-agent/sample_image" http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246 --header "Upload-Offset: 0" --header "Expect:" -i --limit-rate 200K

#the above request limits transfer for testing purposes
#'ctl c' out after a few seconds, to stop file transfer
#check image_offset with a GET

Check upload - GET

Request

curl -i -X GET http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246

Response

HTTP/1.1 200 OK
Content-Type: application/json
Date: Sat, 24 Aug 2019 00:30:00 GMT
Content-Length: 245

{"owner":"alpha","cluster_name":"beta","type":"container","image_name":"asdf246","image_offset":4079616,"image_length":29718177,"upload_complete":false,"description":{"image_records":[{"image_record_name":"iuysdi1234","repo":"icn","tag":"2"}]}}

#from our response you can see that image_offset is still less than image_length and #upload_complete is still false
#next we use the dd command (no limiting this time)

Request

dd if=/home/enyi/workspace/icn/cmd/bpa-restapi-agent/sample_image skip=4079616 bs=1 | curl --request PATCH --data-binary @- http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246 --header "Upload-Offset: 4079616" --header "Expect:" -i

#the request skips already uploaded 4079616 bytes of data

Response

25638561+0 records in
25638561+0 records out
25638561 bytes (26 MB, 24 MiB) copied, 207.954 s, 123 kB/s
HTTP/1.1 204 No Content
Upload-Offset: 29718177
Date: Sat, 24 Aug 2019 00:43:18 GMT

Update image description - PUT

# let's change the tag in description from 1 to latest
# once the  change is made in sample.json (or your json file)

Request

curl -i -F "metadata=<sample.json;type=application/json" -F file=@/home/enyi/workspace/icn/cmd/bpa-restapi-agent/sample.json -X PUT http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246

Response

HTTP/1.1 100 Continue

HTTP/1.1 201 Created
Content-Type: application/json
Date: Fri, 23 Aug 2019 17:21:01 GMT
Content-Length: 239

{"owner":"alpha","cluster_name":"beta","type":"container","image_name":"asdf246","image_offset":0,"image_length":29718177,"upload_complete":false,"description":{"image_records":[{"image_record_name":"iuysdi1234","repo":"icn","tag":"2"}]}}

Delete an image - DELETE

Request

curl -i -X DELETE http://localhost:9015/v1/baremetalcluster/alpha/beta/container_images/asdf246

Response

# Cloud Storage with MinIO

Start MinIO server daemon with docker command before running REST API agent,
default settings in config/config.go.
AccessKeyID: ICN-ACCESSKEYID
SecretAccessKey: ICN-SECRETACCESSKEY
MinIO Port: 9000

You can setup MinIO server my the following command with default credentials.
```
$ docker run -p 9000:9000 --name minio1 \
  -e "MINIO_ACCESS_KEY=ICN-ACCESSKEYID" \
  -e "MINIO_SECRET_KEY=ICN-SECRETACCESSKEY" \
  -v /mnt/data:/data \
  minio/minio server /data
```
Also there is a Kubernetes deployment for MinIO server in standalone mode.
```
$ cd deploy/kud-plugin-addons/minio
$ ./install.sh
```
You can check the status by opening a browser: http://127.0.0.1:9000/

MinIO Client implementation integrated in REST API agent and will automatically
initialize in main.go, and create 3 buckets: binary, container, operatingsystem.
The Upload image will "PUT" to corresponding buckets by HTTP PATCH request url.
