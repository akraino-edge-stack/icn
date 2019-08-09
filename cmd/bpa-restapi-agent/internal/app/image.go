package app

import (
  //"encoding/base64"
	"encoding/json"
	//"io/ioutil"

	"bpa-restapi-agent/internal/db"

	pkgerrors "github.com/pkg/errors"
)

// Image contains the parameters needed for Image information
type Image struct {
	Owner          			string               `json:"owner"`
	ClusterName         string               `json:"cluster_name"`
	Type                string               `json:"type"`
	ImageName           string               `json:"image_name"`
	Config							string 							 `json:"config"`
	ImageOffset					int32								 `json:"image_offset"`
	ImageLength					int32								 `json:"image_length"`
	UploadComplete			bool								 `json:"upload_complete"`
	Description         ImageRecordList      `json:"description"`
}

type ImageRecordList struct {
	ImageRecords []map[string]string `json:"image_records"`
}

// ImageKey is the key structure that is used in the database
type ImageKey struct {
	// Owner            string     `json:"owner"`
	// ClusterName      string     `json:"cluster_name"`
	ImageName        string     `json:"image_name"`
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
	GetImageRecordByName(imgname, imageName string) (map[string]string, error)
}

// ImageClient implements the ImageManager
// It will also be used to maintain some localized state
type ImageClient struct {
	storeName string
	tagMeta   string
}

// To Do - Fix repetition in
// NewImageClient returns an instance of the ImageClient
// which implements the ImageManager
func NewBinaryImageClient() *ImageClient {
	return &ImageClient{
		storeName: "binary_image",
		tagMeta:   "metadata",
	}
}

func NewContainerImageClient() *ImageClient {
	return &ImageClient{
		storeName: "container_image",
		tagMeta:   "metadata",
	}
}

func NewOSImageClient() *ImageClient {
	return &ImageClient{
		storeName: "os_image",
		tagMeta:   "metadata",
	}
}

// Create an entry for the Image resource in the database`
func (v *ImageClient) Create(c Image) (Image, error) {

	//Construct composite key consisting of name
	key := ImageKey{
		// Owner:	c.Owner,
		// ClusterName:	c.ClusterName,
		ImageName: c.ImageName,
	}

	//Check if this Image already exists
	_, err := v.Get(c.ImageName)
	if err == nil {
		return Image{}, pkgerrors.New("Image already exists")
	}

	err = db.DBconn.Create(v.storeName, key, v.tagMeta, c)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Creating DB Entry")
	}

	return c, nil
}

// Get returns Image for corresponding to name
func (v *ImageClient) Get(imageName string) (Image, error) {

	//Construct the composite key to select the entry
	key := ImageKey{
		// Owner:	ownerName,
		// ClusterName:	clusterName,
		ImageName: imageName,
	}

	value, err := db.DBconn.Read(v.storeName, key, v.tagMeta)
	if err != nil {
		return Image{}, pkgerrors.Wrap(err, "Get Image")
	}

	//value is a byte array
	if value != nil {
		c := Image{}
		err = db.DBconn.Unmarshal(value, &c)
		if err != nil {
			return Image{}, pkgerrors.Wrap(err, "Unmarshaling Value")
		}
		return c, nil
	}

	return Image{}, pkgerrors.New("Error getting Connection")
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

// Delete the Image from database
func (v *ImageClient) Delete(imageName string) error {

	//Construct the composite key to select the entry
	key := ImageKey{
		// Owner:	ownerName,
		// ClusterName:	clusterName,
		ImageName: imageName,
	}
	err := db.DBconn.Delete(v.storeName, key, v.tagMeta)
	if err != nil {
		return pkgerrors.Wrap(err, "Delete Image")
	}
	return nil
}
