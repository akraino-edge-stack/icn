package app

import (
	"bpa-restapi-agent/internal/db"
	"encoding/json"
	"os"
	"os/user"
	"path"

	pkgerrors "github.com/pkg/errors"
)

// Image contains the parameters needed for Image information
type Image struct {
	Owner          string          `json:"owner"`
	ClusterName    string          `json:"cluster_name"`
	Type           string          `json:"type"`
	ImageName      string          `json:"image_name"`
	ImageOffset    *int            `json:"image_offset"`
	ImageLength    int             `json:"image_length"`
	UploadComplete *bool           `json:"upload_complete"`
	Description    ImageRecordList `json:"description"`
}

type ImageRecordList struct {
	ImageRecords []map[string]string `json:"image_records"`
}

// ImageKey is the key structure that is used in the database
type ImageKey struct {
	ImageName string `json:"image_name"`
}

// We will use json marshalling to convert to string to
// preserve the underlying structure.
func (dk ImageKey) String() string {
	out, err := json.Marshal(dk)
	if err != nil {
		return ""
	}

	return string(out)
}

// ImageManager is an interface that exposes the Image functionality
type ImageManager interface {
	Create(c Image) (Image, error)
	Get(imageName string) (Image, error)
	Delete(imageName string) error
	Update(imageName string, c Image) (Image, error)
	GetImageRecordByName(imgname, imageName string) (map[string]string, error)
	GetDirPath(imageName string) (string, string, error)
}

// Interface to aid unit test by mocking third party packages
type Utility interface {
	GetCurrentUser() (*user.User, error)
	DBCreate(storeName string, key ImageKey, meta string, c Image) error
	DBRead(storeName string, key ImageKey, meta string) ([]byte, error)
	DBUnmarshal(value []byte) (Image, error)
	OSMakeDir(dirpath string, perm int) error
	OSCreateFile(filePath string) error
	GetPath(user *user.User, imageName string, storeName string) (string, string)
	DBDelete(storeName string, key ImageKey, meta string) error
	OSRemove(filePath string) error
	DBUpdate(storeName string, key ImageKey, tagMeta string, c Image) error
}

// ImageClient implements the ImageManager
// It will also be used to maintain some localized state
type ImageClient struct {
	util      Utility
	storeName string
	tagMeta   string
}

type DBService struct {
}

// To Do - Fix repetition in
// NewImageClient returns an instance of the ImageClient
// which implements the ImageManager
func NewBinaryImageClient() *ImageClient {
    service := DBService{}
	return &ImageClient{
        util: service,
		storeName: "binary_images",
		tagMeta:   "metadata",
	}
}

func NewContainerImageClient() *ImageClient {
    service := DBService{}
	return &ImageClient{
        util: service,
		storeName: "container_images",
		tagMeta:   "metadata",
	}
}

func NewOSImageClient() *ImageClient {
    service := DBService{}
	return &ImageClient{
        util: service,
		storeName: "os_images",
		tagMeta:   "metadata",
	}
}

// Create an entry for the Image resource in the database`
func (v *ImageClient) Create(c Image) (Image, error) {
	//Construct composite key consisting of name
	key := ImageKey{
		ImageName: c.ImageName,
	}

	//Check if this Image already exists
	_, err := v.Get(c.ImageName)
	if err == nil {
		return Image{}, pkgerrors.New("Image already exists")
	}

	err = v.util.DBCreate(v.storeName, key, v.tagMeta, c)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Creating DB Entry")
	}

	err = v.CreateFile(c)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Creating File in FS")
	}

	return c, nil
}

func (d DBService) DBCreate(storeName string, key ImageKey, meta string, c Image) error {

	//Construct composite key consisting of name
	err := db.DBconn.Create(storeName, key, meta, c)
	if err != nil {
		return pkgerrors.Wrap(err, "Creating DB Entry")
	}

	return nil
}

// Create file

func (v *ImageClient) CreateFile(c Image) error {
	filePath, dirPath, err := v.GetDirPath(c.ImageName)
	if err != nil {
		return pkgerrors.Wrap(err, "Get file path")
	}
	err = v.util.OSMakeDir(dirPath, 0744)
	if err != nil {
		return pkgerrors.Wrap(err, "Make image directory")
	}
	err = v.util.OSCreateFile(filePath)
	if err != nil {
		return pkgerrors.Wrap(err, "Create image file")
	}

	return nil
}

func (d DBService) OSMakeDir(dirPath string, perm int) error {
	err := os.MkdirAll(dirPath, 0744)
	if err != nil {
		return pkgerrors.Wrap(err, "Make image directory")
	}
	return nil
}

func (d DBService) OSCreateFile(filePath string) error {
	file1, err := os.Create(filePath)
	if err != nil {
		return pkgerrors.Wrap(err, "Create image file")
	}
	defer file1.Close()

	return nil
}

// Get returns Image for corresponding to name
func (v *ImageClient) Get(imageName string) (Image, error) {

	//Construct the composite key to select the entry
	key := ImageKey{
		// Owner:	ownerName,
		// ClusterName:	clusterName,
		ImageName: imageName,
	}

	value, err := v.util.DBRead(v.storeName, key, v.tagMeta)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Get Image")
	}

	//value is a byte array
	if value != nil {
		c, err := v.util.DBUnmarshal(value)
		if err != nil {
			return Image{}, pkgerrors.Wrap(err, "Unmarshaling Value")
		}
		return c, nil
	}

	return Image{}, pkgerrors.New("Error getting Connection")
}

func (d DBService) DBRead(storeName string, key ImageKey, meta string) ([]byte, error) {
	value, err := db.DBconn.Read(storeName, key, meta)
	if err != nil {
		return []byte{}, pkgerrors.Wrap(err, "Get Image")
	}

	return value, nil
}

func (d DBService) DBUnmarshal(value []byte) (Image, error) {
	c := Image{}
	err := db.DBconn.Unmarshal(value, &c)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Unmarshaling Value")
	}

	return c, nil
}

func (v *ImageClient) GetImageRecordByName(imgName string,
	imageRecordName string) (map[string]string, error) {

	img, err := v.Get(imgName)
	if err != nil {
		return nil, pkgerrors.Wrap(err, "Error getting image")
	}

	for _, value := range img.Description.ImageRecords {
		if imageRecordName == value["image_record_name"] {
			return value, nil
		}
	}

	return nil, pkgerrors.New("Image record " + imageRecordName + " not found")
}

func (v *ImageClient) GetDirPath(imageName string) (string, string, error) {
	u, err := v.util.GetCurrentUser()
	filePath, dirPath := v.util.GetPath(u, imageName, v.storeName)

	return filePath, dirPath, err
}

// Delete the Image from database
func (v *ImageClient) Delete(imageName string) error {

	//Construct the composite key to select the entry
	key := ImageKey{
		// Owner:	ownerName,
		// ClusterName:	clusterName,
		ImageName: imageName,
	}
	err := v.util.DBDelete(v.storeName, key, v.tagMeta)

	//Delete image from FS
	filePath, _, err := v.GetDirPath(imageName)
	if err != nil {
		return pkgerrors.Wrap(err, "Get file path")
	}
	err = v.util.OSRemove(filePath)

	return nil
}

func (d DBService) OSRemove(filePath string) error {
	err := os.Remove(filePath)
	if err != nil {
		return pkgerrors.Wrap(err, "Delete image file")
	}

	return nil
}

func (d DBService) DBDelete(storeName string, key ImageKey, tagMeta string) error {
	err := db.DBconn.Delete(storeName, key, tagMeta)
	if err != nil {
		return pkgerrors.Wrap(err, "Delete Image")
	}

	return nil
}

// Update an entry for the image in the database
func (v *ImageClient) Update(imageName string, c Image) (Image, error) {

	key := ImageKey{
		ImageName: imageName,
	}

	//Check if this Image exists
	_, err := v.Get(imageName)
	if err != nil {
		return Image{}, pkgerrors.New("Update Error - Image doesn't exist")
	}

	err = v.util.DBUpdate(v.storeName, key, v.tagMeta, c)

	return c, nil
}

func (d DBService) DBUpdate(storeName string, key ImageKey, tagMeta string, c Image) error {
	err := db.DBconn.Update(storeName, key, tagMeta, c)
	if err != nil {
		return pkgerrors.Wrap(err, "Updating DB Entry")
	}

	return nil
}

// Define GetCurrentUser
func (d DBService) GetCurrentUser() (*user.User, error) {
	u, err := user.Current()
	if err != nil {
		return nil, pkgerrors.Wrap(err, "Current user")
	}

	return u, nil
}

func (d DBService) GetPath(user *user.User, imageName string, storeName string) (string, string) {
	home := user.HomeDir
	dirPath := path.Join(home, "images", storeName)
	filePath := path.Join(dirPath, imageName)

	return filePath, dirPath
}
