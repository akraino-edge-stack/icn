
package api

import (
	"bytes"
	"encoding/base64"
	"encoding/json"
	"io"
	"io/ioutil"
	"net/http"

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

// CreateHandler handles creation of the image entry in the database

func (h imageHandler) createHandler(w http.ResponseWriter, r *http.Request) {
	var v image.Image

	// Implemenation using multipart form
	// Review and enable/remove at a later date
	// Set Max size to 16mb here
	err := r.ParseMultipartForm(16777216)
	if err != nil {
		http.Error(w, err.Error(), http.StatusUnprocessableEntity)
		return
	}

	jsn := bytes.NewBuffer([]byte(r.FormValue("metadata")))
	err = json.NewDecoder(jsn).Decode(&v)
	switch {
	case err == io.EOF:
		http.Error(w, "Empty body", http.StatusBadRequest)
		return
	case err != nil:
		http.Error(w, err.Error(), http.StatusUnprocessableEntity)
		return
	}

	// Name is required.
	if v.ImageName == "" {
		http.Error(w, "Missing name in POST request", http.StatusBadRequest)
		return
	}

	// Owner is required.
	if v.Owner == "" {
		http.Error(w, "Missing Owner in POST request", http.StatusBadRequest)
		return
	}

	//Read the file section and ignore the header
	file, _, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Unable to process file", http.StatusUnprocessableEntity)
		return
	}

	defer file.Close()

	//Convert the file content to base64 for storage
	content, err := ioutil.ReadAll(file)
	if err != nil {
		http.Error(w, "Unable to read file", http.StatusUnprocessableEntity)
		return
	}

	v.Config = base64.StdEncoding.EncodeToString(content)

	ret, err := h.client.Create(v)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	err = json.NewEncoder(w).Encode(ret)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

// getHandler handles GET operations on a particular name
// Returns an Image
func (h imageHandler) getHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	// ownerName := vars["owner"]
	// clusterName := vars["clustername"]
	imageName := vars["imgname"]

	ret, err := h.client.Get(imageName)
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

// deleteHandler handles DELETE operations on a particular record
func (h imageHandler) deleteHandler(w http.ResponseWriter, r *http.Request) {
	vars := mux.Vars(r)
	// ownerName := vars["owner"]
	// clusterName := vars["clustername"]
	imageName := vars["imgname"]

	err := h.client.Delete(imageName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	w.WriteHeader(http.StatusNoContent)
}
