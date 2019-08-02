// api/api_images.go

package api

import (
  //"io"
	//"io/ioutil"
	"encoding/json"
	"log"
	"net/http"
)

// Controller
type Controller struct {
	Repository Repository
}

func (c *Controller) FindImages(w http.ResponseWriter, r *http.Request) {
	images := c.Repository.GetImages() //list all Images
	log.Println(images)
	data, _ := json.Marshal(images)
	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.WriteHeader(http.StatusOK)
	w.Write(data)
	return
}
