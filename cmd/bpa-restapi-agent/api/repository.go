// ICN application
package api

import (
  "fmt"
  "log"

  "gopkg.in/mgo.v2"
  //"gopkg.in/mgo.v2/bson"
)

//Repository
type Repository struct{}

// DB Server
const SERVER = "localhost:27017"

// DBName
const DBNAME = "images"

// DOCName
const DOCNAME = "containers"

// GetImages
func (r Repository) GetImages() Images {
  session, err := mgo.Dial(SERVER)
  if err != nil {
    fmt.Println("Failed to establish connection to MongoDB:", err)
  }
  defer session.Close()
  c := session.DB(DBNAME).C(DOCNAME)
  results := Images{}
  if err := c.Find(nil).All(&results); err != nil {
    fmt.Println("Failed to write results:", err)
  }
  return results
}

// PUT
func (r Repository) UpdateImage(image Image) bool {
  session, err := mgo.Dial(SERVER)
  defer session.Close()
  session.DB(DBNAME).C(DOCNAME).UpdateId(image.ID, image)

  if err != nil{
    log.Fatal(err)
    return  false
  }
  return true
}
