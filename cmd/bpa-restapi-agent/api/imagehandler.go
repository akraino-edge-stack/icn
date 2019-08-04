
package api

import (
	// "bytes"
	// "encoding/base64"
	"encoding/json"
	// "io"
	// "io/ioutil"
	"net/http"
	//
	image "icn/cmd/bpa-restapi-agent/internal/app"

	"github.com/gorilla/mux"
)

// imageHandler is used to store backend implementations objects
// Also simplifies mocking for unit testing purposes
type imageHandler struct {
	// Interface that implements Image operations
	// We will set this variable with a mock interface for testing
	client image.ImageManager
}

// getHandler handles GET operations on a particular name
// Returns an Image
func (h imageHandler) getHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	name := vars["imgname"]

	ret, err := h.client.Get(name)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	err = json.NewEncoder(w).Encode(ret)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}
