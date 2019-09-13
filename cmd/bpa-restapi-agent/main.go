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


  "github.com/gorilla/handlers"

  "bpa-restapi-agent/api"
  utils "bpa-restapi-agent/internal"
  "bpa-restapi-agent/internal/auth"
  "bpa-restapi-agent/internal/config"
)

func main() {
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
  tlsConfig, err := auth.GetTLSConfig("ca.cert", "server.cert", "server.key")
  if err != nil {
    log.Println("Error Getting TLS Configuration. Starting without TLS...")
    log.Fatal(httpServer.ListenAndServe())
  } else {
    httpServer.TLSConfig = tlsConfig
    // empty strings because tlsconfig already has this information
    err = httpServer.ListenAndServeTLS("", "")
  }
}
