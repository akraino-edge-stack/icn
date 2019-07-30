package db

import (
	"encoding/json"
	"reflect"

	pkgerrors "github.com/pkg/errors"
)

// DBconn interface used to talk to a concrete Database connection
var DBconn Store

// Key is an interface that will be implemented by anypackage
// that wants to use the Store interface. This allows various
// db backends and key types.
type Key interface {
	String() string
}

// Store is an interface for accessing a database
type Store interface {
	// Returns nil if db health is good
	HealthCheck() error

	// Unmarshal implements any unmarshaling needed for the database
	Unmarshal(inp []byte, out interface{}) error

	// Creates a new master table with key and links data with tag and
	// creates a pointer to the newly added data in the master table
	Create(table string, key Key, tag string, data interface{}) error

	// Reads data for a particular key with specific tag.
	Read(table string, key Key, tag string) ([]byte, error)

	// Update data for particular key with specific tag
	Update(table string, key Key, tag string, data interface{}) error

	// Deletes a specific tag data for key.
	// TODO: If tag is empty, it will delete all tags under key.
	Delete(table string, key Key, tag string) error

	// Reads all master tables and data from the specified tag in table
	ReadAll(table string, tag string) (map[string][]byte, error)
}

// CreateDBClient creates the DB client
func CreateDBClient(dbType string) error {
	var err error
	switch dbType {
	case "mongo":
		// create a mongodb database with ICN as the name
		DBconn, err = NewMongoStore("icn", nil)
	default:
		return pkgerrors.New(dbType + "DB not supported")
	}
	return err
}

// Serialize converts given data into a JSON string
func Serialize(v interface{}) (string, error) {
	out, err := json.Marshal(v)
	if err != nil {
		return "", pkgerrors.Wrap(err, "Error serializing "+reflect.TypeOf(v).String())
	}
	return string(out), nil
}

// DeSerialize converts string to a json object specified by type
func DeSerialize(str string, v interface{}) error {
	err := json.Unmarshal([]byte(str), &v)
	if err != nil {
		return pkgerrors.Wrap(err, "Error deSerializing "+str)
	}
	return nil
}
