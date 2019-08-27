package api

import (
	"bytes"
	//"encoding/base64"
	"encoding/json"
	"fmt"
	"io"
	"io/ioutil"
	"net/http"
	"os"
	"log"
	"strconv"

	image "bpa-restapi-agent/internal/app"
	minioc "bpa-restapi-agent/internal/storage"

	"github.com/gorilla/mux"
)

// imageHandler is used to store backend implementations objects
// Also simplifies mocking for unit testing purposes
type imageHandler struct {
	// Interface that implements Image operations
	// We will set this variable with a mock interface for testing
	client image.ImageManager
	dirPath string
	minioI minioc.MinIOInfo
	storeName string  // as minio client bucketname
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

	if v.ImageLength == 0 {
		e := "Improper upload length"
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(e))
		return
	}

	//Read the file section and ignore the header
	file, _, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Unable to process file", http.StatusUnprocessableEntity)
		return
	}

	defer file.Close()


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
	imageName := vars["imgname"]

	err := h.client.Delete(imageName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	h.minioI.DeleteImage(h.storeName, imageName)

	w.WriteHeader(http.StatusNoContent)
}

// UpdateHandler handles Update operations on a particular image
func (h imageHandler) updateHandler(w http.ResponseWriter, r *http.Request) {
	var v image.Image
	vars := mux.Vars(r)
	imageName := vars["imgname"]

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
		http.Error(w, "Missing name in PUT request", http.StatusBadRequest)
		return
	}

	// Owner is required.
	if v.Owner == "" {
		http.Error(w, "Missing Owner in PUT request", http.StatusBadRequest)
		return
	}

	//Read the file section and ignore the header
	file, _, err := r.FormFile("file")
	if err != nil {
		http.Error(w, "Unable to process file", http.StatusUnprocessableEntity)
		return
	}

	defer file.Close()

	ret, err := h.client.Update(imageName, v)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

/**	log.Printf("Start to upload image, bucket: %s, image: %s, dir: %s.\n", h.storeName, imageName, h.dirPath)
	putbytes, err := h.minioI.PutImage(h.storeName, imageName, h.dirPath)
	if err != nil || putbytes == 0  {
		log.Printf("MinIO put failed: %s", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}*/

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	err = json.NewEncoder(w).Encode(ret)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
}

// File upload is handled by the patchHandler

func (h imageHandler) patchHandler(w http.ResponseWriter, r *http.Request) {
	log.Println("going to patch file")
	vars := mux.Vars(r)
	imageName := vars["imgname"]
	file, err := h.client.Get(imageName)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	if *file.UploadComplete == true {
		e := "Upload already completed"
		w.WriteHeader(http.StatusUnprocessableEntity)
		w.Write([]byte(e))
		log.Println("Upload already completed")
		return
	}
	off, err := strconv.Atoi(r.Header.Get("Upload-Offset"))
	if err != nil {
		log.Println("Improper upload offset", err)
		w.WriteHeader(http.StatusBadRequest)
		return
	}
	log.Printf("Upload offset %d\n", off)
	if *file.ImageOffset != off {
		e := fmt.Sprintf("Expected Offset %d got offset %d", *file.ImageOffset, off)
		w.WriteHeader(http.StatusConflict)
		w.Write([]byte(e))
		log.Printf("Expected Offset:%d doesn't match got offset:%d\n", *file.ImageOffset, off)
		return
	}

	log.Println("Content length is", r.Header.Get("Content-Length"))
	clh := r.Header.Get("Content-Length")
	cl, err := strconv.Atoi(clh)
	if err != nil {
		log.Println("unknown content length")
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	if cl != (file.ImageLength - *file.ImageOffset) {
		e := fmt.Sprintf("Content length doesn't match upload length. Expected content length %d got %d", file.ImageLength-*file.ImageOffset, cl)
		log.Println(e)
		w.WriteHeader(http.StatusBadRequest)
		w.Write([]byte(e))
		return
	}

	body, err := ioutil.ReadAll(r.Body)
	if err != nil {
		log.Printf("Received file partially %s\n", err)
		log.Println("Size of received file ", len(body))
	}

	fp, _, err := h.client.GetDirPath(imageName)
	if err != nil {
		log.Printf("unable to get file path %s\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	f, err := os.OpenFile(fp, os.O_APPEND|os.O_WRONLY, 0644)
	if err != nil {
		log.Printf("unable to open file %s\n", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}
	defer f.Close()

	n, err := f.WriteAt(body, int64(off))
	if err != nil {
		log.Printf("unable to write %s", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}

	log.Printf("Start to Patch image, bucket: %s, image: %s, dirpath: %s, offset: %d, n: %d\n",
		h.storeName, imageName, fp, *file.ImageOffset, n)
	uploadbytes, err := h.minioI.PatchImage(h.storeName, imageName, fp, int64(*file.ImageOffset), int64(n))
	//uploadbytes, err := h.minioI.PutImage(h.storeName, imageName, fp)
	if err != nil || uploadbytes == 0  {
		log.Printf("MinIO upload with offset %d failed: %s", *file.ImageOffset, err)
		w.WriteHeader(http.StatusInternalServerError)
		return
    }

	log.Println("number of bytes written ", n)
	no := *file.ImageOffset + n
	file.ImageOffset = &no

	uo := strconv.Itoa(*file.ImageOffset)
	w.Header().Set("Upload-Offset", uo)
	if *file.ImageOffset == file.ImageLength {
		log.Println("upload completed successfully")
		*file.UploadComplete = true
	}

	_, err = h.client.Update(imageName, file)
	if err != nil {
		log.Println("Error while updating file", err)
		w.WriteHeader(http.StatusInternalServerError)
		return
	}



	w.WriteHeader(http.StatusNoContent)

	return

}
