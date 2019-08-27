package storage

import (
    "github.com/minio/minio-go/v6"
    "bpa-restapi-agent/internal/config"

    "log"
    "os"
)

type MinIOInfo struct {
	minioC         *minio.Client		`json:"minio client"`
}

// Initialize the MinIO server, create buckets
func Initialize() (MinIOInfo, error) {
	endpoint := config.GetConfiguration().MinIOAddress + ":" + config.GetConfiguration().MinIOPort
    accessKeyID := config.GetConfiguration().AccessKeyID
    secretAccessKey := config.GetConfiguration().SecretAccessKey
    useSSL := false

    minioInfo := MinIOInfo{}
    // Initialize minio client object.
    minioClient, err := minio.New(endpoint, accessKeyID, secretAccessKey, useSSL)
    if err != nil {
        log.Fatalln(err)
        return minioInfo, err
    }

    // Make a new bucket.
    bucketNames := []string{"binary", "container", "operatingsystem"}
    location := "us-west-1"

    for _, bucketName := range bucketNames {
        err := minioClient.MakeBucket(bucketName, location)
        if err != nil {
            // Check to see if we already own this bucket (which happens if you run this twice)
            exists, errBucketExists := minioClient.BucketExists(bucketName)
            if errBucketExists == nil && exists {
                log.Printf("We already own %s\n", bucketName)
            } else {
                log.Fatalln(err)
                return minioInfo, err
            }
        } else {
            log.Printf("Successfully created %s\n", bucketName)
        }
    }

    minioInfo.minioC = minioClient
    return minioInfo, nil
}

func (m MinIOInfo) PutImage(bucketName string, objName string, localPath string) (int64, error) {

    //contentType := "multipart/form-data"
    contentType := "application/octet-stream"

    // Upload the zip file with FPutObject
    n, err := m.minioC.FPutObject(bucketName, objName, localPath, minio.PutObjectOptions{ContentType:contentType})
    if err != nil {
		log.Fatalln(err)
		return n, err
    }

    fileInfo, _ := os.Stat(localPath)
    fileSize := fileInfo.Size()

    if n != int64(fileSize) {
        log.Printf("FPutObject failed %s of size %d\n", objName, n)
        return n, err
    }

	log.Printf("Successfully uploaded %s of size %d\n", objName, n)
	return n, nil
}

func (m MinIOInfo) PatchImage(bucketName string, objName string, localPath string, offset int64, objSize int64) (int64, error) {

    var n = int64(0)

    tempFile, err := os.Open(localPath)
    if err != nil {
        log.Fatalln(err)
        return n, err
    }

    defer tempFile.Close()

    if _, err := tempFile.Seek(offset, 0); err != nil {
        log.Printf("PatchImage seek %s failed: %s", tempFile.Name(), err)
        return n, err
    }

    objInfo, err := m.minioC.StatObject(bucketName, objName, minio.StatObjectOptions{})
    var objHealthy = true
    if err != nil {
        objHealthy = false
    } else if objInfo.Size != offset || objInfo.Size == 0 {
        objHealthy = false
    }

    var objNameTemp = objName
    if objHealthy {
        objNameTemp = objName + ".tmp"
    }

    contentType := "application/octet-stream"
    n, err = m.minioC.PutObject(bucketName, objNameTemp, tempFile, objSize, minio.PutObjectOptions{ContentType:contentType})
    if err != nil {
        log.Fatalln(err)
        return n, err
    }

    if n != objSize {
        log.Printf("PatchImage PutObject %s failed with bytes: %d", tempFile.Name(), n)
        return n, err
    }

    if objHealthy {
        src1 := minio.NewSourceInfo(bucketName, objName, nil)
        src2 := minio.NewSourceInfo(bucketName, objNameTemp, nil)
        srcs := []minio.SourceInfo{src1, src2}

        dst, err := minio.NewDestinationInfo(bucketName, objName, nil, nil)
        if err != nil {
            log.Printf("NewDestinationInfo failed", err)
            return n, err
        }

        // There is issue, the last src should be the smallest obj size
        err = m.minioC.ComposeObject(dst, srcs)
        if err != nil {
            log.Printf("ComposeObject failed", err)
            return n, err
        }
    }

    log.Printf("Successfully PatchImage %s of size %d\n", objName, n)
    return n, nil
}

func (m MinIOInfo) GetImage(bucketName string, objName string, localPath string) (error) {

    // Upload the zip file with FPutObject
    err := m.minioC.FGetObject(bucketName, objName, localPath, minio.GetObjectOptions{})
    if err != nil {
        log.Fatalln(err)
        return err
    }

    log.Printf("Successfully downloaded %s\n", objName)
    return err
}

func (m MinIOInfo) DeleteImage(bucketName string, objName string) (error) {

    err := m.minioC.RemoveObject(bucketName, objName)
    if err != nil {
        log.Printf("MinIO Remove object %s failed\n", bucketName)
        return err
    }

    return nil
}

func (m MinIOInfo) CleanupImages(bucketName string) (error) {
    // create a done channel to control 'ListObjectsV2' go routine.
    doneCh := make(chan struct{})
    defer close(doneCh)

    for objCh := range m.minioC.ListObjectsV2(bucketName, "", true, doneCh) {
        if objCh.Err != nil {
            return objCh.Err
        }
        if objCh.Key != "" {
            err := m.minioC.RemoveObject(bucketName, objCh.Key)
            if err != nil {
                return err
            }
        }
    }
    for objPartInfo := range m.minioC.ListIncompleteUploads(bucketName, "", true, doneCh) {
        if objPartInfo.Err != nil {
            return objPartInfo.Err
        }
        if objPartInfo.Key != "" {
            err := m.minioC.RemoveIncompleteUpload(bucketName, objPartInfo.Key)
            if err != nil {
                return err
            }
        }
    }

    return nil
}
