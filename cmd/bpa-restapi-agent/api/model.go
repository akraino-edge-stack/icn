// api/model.go

package api

type Image struct {

  ID string `json:"json:"_id"`

	Name string `json:"json:"name,omitempty"`

	ImageId string `json:"image_id,omitempty"`

	Repo string `json:"repo,omitempty"`

	Tag string `json:"tag,omitempty"`

	Description string `json:"description,omitempty"`
}

type Images []Image
