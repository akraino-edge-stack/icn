// api/routers.go

package api

import (
  "net/http"
  "strings"

  "icn/cmd/bpa-restapi-agent/logger"

  "github.com/gorilla/mux"
)

var controller = &Controller{Repository: Repository{}}

type Route struct {
  Name        string
  Method      string
  Pattern     string
  HandlerFunc http.HandlerFunc
}

type Routes []Route

func NewRouter() *mux.Router {
  router := mux.NewRouter().StrictSlash(true)
  for _, route := range routes {
  var handler http.Handler
  handler = route.HandlerFunc
  handler = logger.Logger(handler, route.Name)

  router.
    Methods(route.Method).
    Path(route.Pattern).
    Name(route.Name).
    Handler(handler)
}

return router
}

var routes = Routes{

  Route{
    "FindImages",
    strings.ToUpper("Get"),
    "/",
    controller.FindImages,
  },
}
