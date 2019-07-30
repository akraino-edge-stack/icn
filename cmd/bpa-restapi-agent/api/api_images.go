// api/api_images.go

package api

import (
  "io"
	"io/ioutil"
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

func (c *Controller) UpdateImage(w http.ResponseWriter, r *http.Request) {
	var image Image
	body, err := ioutil.ReadAll(io.LimitReader(r.Body, 1048576))
	if err != nil {
		log.Fatalln("Error UpdateImage", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	if err := r.Body.Close(); err != nil {
		log.Fatalln("Error UpdateImage", err)
	}
	if err := json.Unmarshal(body, &image); err != nil {
		w.Header().Set("Content-Type", "application/json; charset=UTF-8")
		w.WriteHeader(422)
		if err := json.NewEncoder(w).Encode(err); err != nil {
			log.Fatalln("Error UpdateImage unmarshalling data", err)
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
	}
	success := c.Repository.UpdateImage(image)
	if !success {
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

  w.Header().Set("Content-Type", "application/json; charset=UTF-8")
  w.Header().Set("Access-Control-Allow-Origin", "*")
  w.WriteHeader(http.StatusOK)
  return
}
