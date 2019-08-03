package app

import (
	"encoding/base64"
	"encoding/json"
	"io/ioutil"

	"icn/cmd/bpa-restapi-agent/internal/db"

	pkgerrors "github.com/pkg/errors"
)

// Image contains the parameters needed for Image information
type Image struct {
	ImageName           string               `json:"image-name"`
  Repository          strings              `json:"repo"`
	Tag                 string               `json:"tag"`
	Description         string               `json:"description"`
	OtherValues         ImageRecordList      `json:"other-values"`
}

type ImageRecordList struct {
	ImageRecords []map[string]string `json:"image-records"`
}

// ImageKey is the key structure that is used in the database
type ImageKey struct {
	ImageName string `json:"image-name"`
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

// ImageManager is an interface thae exposes the Image functionality
type ImageManager interface {
	Create(c Connection) (Connection, error)
	Get(name string) (Connection, error)
	Delete(name string) error
	GetImageRecordByName(imagename string, name string) (map[string]string, error)
}

// ImageClient implements the ImageManager
// It will also be used to maintain some localized state
type ImageClient struct {
	storeName string
	tagMeta   string
}

// NewImageClient returns an instance of the ImageClient
// which implements the ImageManager
func NewImageClient() *ImageClient {
	return &ImageClient{
		storeName: "image",
		tagMeta:   "metadata",
	}
}

// Create an entry for the Image resource in the database`
func (v *ImageClient) Create(c Image) (Image, error) {

	//Construct composite key consisting of name
	key := ImageKey{ImageName: c.ImageName}

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
func (v *ImageClient) Get(name string) (Image, error) {

	//Construct the composite key to select the entry
	key := ImageKey{ImageName: name}
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

	for _, value := range img.OtherValues.ImageRecords {
		if imageRecordName == value["image-record-name"] {
			return value, nil
		}
	}

	return nil, pkgerrors.New("Image record " + ImageRecordName + " not found")
}

// Delete the Image from database
func (v *ImageClient) Delete(name string) error {

	//Construct the composite key to select the entry
	key := ImageKey{ImageName: name}
	err := db.DBconn.Delete(v.storeName, key, v.tagMeta)
	if err != nil {
		return pkgerrors.Wrap(err, "Delete Image")
	}
	return nil
}
