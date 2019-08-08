// api/api_images.go


package api

import (
	image "icn/cmd/bpa-restapi-agent/internal/app"

	"github.com/gorilla/mux"
)

// To Do - Add connection

// NewRouter creates a router that registers the various urls that are supported
func NewRouter(binaryClient image.ImageManager,
							 containerClient image.ImageManager,
							 osClient image.ImageManager) *mux.Router {

	router := mux.NewRouter()

	//Setup the image install api handler here
	if binaryClient == nil {
		binaryClient = image.NewBinaryImageClient()
	}
	binaryHandler := imageHandler{client: binaryClient}
	imgRouter := router.PathPrefix("/v1").Subrouter()
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images", binaryHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.deleteHandler).Methods("DELETE")

	//Setup the _image install api handler here
	if containerClient == nil {
		containerClient = image.NewContainerImageClient()
	}
	containerHandler := imageHandler{client: containerClient}
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images", containerHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.deleteHandler).Methods("DELETE")

	//Setup the os_image install api handler here
	if osClient == nil {
		osClient = image.NewOSImageClient()
	}
	osHandler := imageHandler{client: osClient}
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images", osHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.deleteHandler).Methods("DELETE")


	// Add healthcheck path
	//instRouter.HandleFunc("/healthcheck", healthCheckHandler).Methods("GET")

	return router
}
