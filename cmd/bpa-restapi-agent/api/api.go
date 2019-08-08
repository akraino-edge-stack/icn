// api/api_images.go


package api

import (
	image "icn/cmd/bpa-restapi-agent/internal/app"

	"github.com/gorilla/mux"
)

// To Do - Add connection

// NewRouter creates a router that registers the various urls that are supported
func NewRouter(imageClient image.ImageManager) *mux.Router {

	router := mux.NewRouter()

	//Setup the image install api handler here
	if imageClient == nil {
		imageClient = image.NewImageClient()
	}
	imageHandler := imageHandler{client: imageClient}
	instRouter := router.PathPrefix("/v1").Subrouter()
	instRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/images", imageHandler.createHandler).Methods("POST")
	instRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/images/{imgname}", imageHandler.getHandler).Methods("GET")
	instRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/images/{imgname}", imageHandler.deleteHandler).Methods("DELETE")


	// Add healthcheck path
	//instRouter.HandleFunc("/healthcheck", healthCheckHandler).Methods("GET")

	return router
}
