// api/api_images.go


package api

import (
	"log"

	image "bpa-restapi-agent/internal/app"
	minio "bpa-restapi-agent/internal/storage"

	"github.com/gorilla/mux"
)

// NewRouter creates a router that registers the various urls that are supported
func NewRouter(binaryClient image.ImageManager,
							 containerClient image.ImageManager,
							 osClient image.ImageManager) *mux.Router {

	router := mux.NewRouter()

	minioInfo, err := minio.Initialize()
	if err != nil {
		log.Println("Error while initialize minio client: %s", err)
	}

	//Setup the image uploaad api handler here
	if binaryClient == nil {
		binaryClient = image.NewBinaryImageClient()
	}
	binaryHandler := imageHandler{client: binaryClient, minioI: minioInfo, storeName: "binary"}
	imgRouter := router.PathPrefix("/v1").Subrouter()
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images", binaryHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.deleteHandler).Methods("DELETE")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.updateHandler).Methods("PUT")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/binary_images/{imgname}", binaryHandler.patchHandler).Methods("PATCH")

	//Setup the _image upload api handler here
	if containerClient == nil {
		containerClient = image.NewContainerImageClient()
	}
	containerHandler := imageHandler{client: containerClient, minioI: minioInfo, storeName: "container"}
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images", containerHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.deleteHandler).Methods("DELETE")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.updateHandler).Methods("PUT")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/container_images/{imgname}", containerHandler.patchHandler).Methods("PATCH")

	//Setup the os_image upload api handler here
	if osClient == nil {
		osClient = image.NewOSImageClient()
	}
	osHandler := imageHandler{client: osClient, minioI: minioInfo, storeName: "operatingsystem"}
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images", osHandler.createHandler).Methods("POST")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.getHandler).Methods("GET")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.deleteHandler).Methods("DELETE")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.updateHandler).Methods("PUT")
	imgRouter.HandleFunc("/baremetalcluster/{owner}/{clustername}/os_images/{imgname}", osHandler.patchHandler).Methods("PATCH")

	return router
}
