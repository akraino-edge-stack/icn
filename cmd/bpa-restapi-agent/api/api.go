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
// type Controller struct {
// 	Repository Repository
// }
//
// func (c *Controller) FindImages(w http.ResponseWriter, r *http.Request) {
// 	images := c.Repository.GetImages() //list all Images
// 	log.Println(images)
// 	data, _ := json.Marshal(images)
// 	w.Header().Set("Content-Type", "application/json; charset=UTF-8")
// 	w.Header().Set("Access-Control-Allow-Origin", "*")
// 	w.WriteHeader(http.StatusOK)
// 	w.Write(data)
// 	return
// }
package api

import (
	"icn/cmd/bpa-restapi-agent/internal/app"

	"github.com/gorilla/mux"
)

// To Do - Add connection

// NewRouter creates a router that registers the various urls that are supported
func NewRouter(imageClient image.ImageManager) *mux.Router {

	router := mux.NewRouter()

	//Setup the image api handler here
	if imageClient == nil {
		imageClient = image.NewImageClient()
	}
	imageHandler := imageHandler{client: imageClient}
	instRouter := router.PathPrefix("/v1/baremetalcluster").Subrouter()
	//instRouter.HandleFunc("/{owner}/{clustername}/", imageHandler.createHandler).Methods("POST")
	instRouter.HandleFunc("/{owner}/{clustername}/", imageHandler.getHandler).Methods("GET")
	//instRouter.HandleFunc("/{owner}/{clustername}/", imageHandler.deleteHandler).Methods("DELETE")


	// Add healthcheck path
	//instRouter.HandleFunc("/healthcheck", healthCheckHandler).Methods("GET")

	return router
}
