// main.go
package main

import (
  "log"
  "net/http"

  "github.com/gorilla/handlers"

  "icn/cmd/bpa-restapi-agent/api"
)

func main() {

  log.Printf("Starting Integrated Cloud Native API")
  router := api.NewRouter()
  //CORS for browser testing (ICN_delete)
  allowedOrigins := handlers.AllowedOrigins([]string{"*"})
  allowedMethods := handlers.AllowedMethods([]string{"GET", "POST",
    "DELETE", "PUT"})

  //log.Fatal(http.ListenAndServe(":8080", router))


  // launch server with CORS validations
  log.Fatal(http.ListenAndServe(":9000",
    handlers.CORS(allowedOrigins, allowedMethods) (router)))
}
