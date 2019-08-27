### Running the server
To run the server, follow these simple steps:

```
go run main.go
```

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

