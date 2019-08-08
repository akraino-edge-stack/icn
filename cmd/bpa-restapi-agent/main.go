// main.go
package main

import (
  "context"
  "log"
  "math/rand"
  "net/http"
  "os"
  "os/signal"
  "time"

  //To Do - Implement internal for checking config
  "github.com/gorilla/handlers"

  "icn/cmd/bpa-restapi-agent/api"
  utils "icn/cmd/bpa-restapi-agent/internal"
  "icn/cmd/bpa-restapi-agent/internal/config"
)

// func main() {
//
//   log.Printf("Starting Integrated Cloud Native API")
//   router := api.NewRouter()
//   //CORS for browser testing (ICN_delete)
//   allowedOrigins := handlers.AllowedOrigins([]string{"*"})
//   allowedMethods := handlers.AllowedMethods([]string{"GET", "POST",
//     "DELETE", "PUT"})
//
//   //log.Fatal(http.ListenAndServe(":8080", router))
//
//
//   // launch server with CORS validations (ICN_delete)
//   log.Fatal(http.ListenAndServe(":9000",
//     handlers.CORS(allowedOrigins, allowedMethods) (router)))
// }

func main() {
  // To Do - Implement initial settings
  // check initial config
  err := utils.CheckInitialSettings()
  if err != nil{
    log.Fatal(err)
  }

  rand.Seed(time.Now().UnixNano())

  httpRouter := api.NewRouter(nil, nil, nil)
  // Return http.handler and log requests to Stdout
  loggedRouter := handlers.LoggingHandler(os.Stdout, httpRouter)
  log.Println("Starting Integrated Cloud Native API")

  // Create custom http server
  httpServer := &http.Server{
    Handler: loggedRouter,
    // To Do - Implement config
    Addr:    ":" + config.GetConfiguration().ServicePort,
  }
  connectionsClose := make(chan struct{})
  go func() {
    c := make(chan os.Signal, 1) // create c channel to receive notifications
    signal.Notify(c, os.Interrupt) // register c channel to run concurrently
    <-c
    httpServer.Shutdown(context.Background())
    close(connectionsClose)
  }()

  // Start server
  log.Fatal(httpServer.ListenAndServe())

}
