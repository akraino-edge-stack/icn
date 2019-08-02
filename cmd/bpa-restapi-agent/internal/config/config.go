package config

import (
  "encoding/json"
  "log"
  "os"
)

type Configuration struct {
  Password        string `json: "password"`
  DatabaseAddress string  `json: "database-address"`
  DatabaseType    string  `json:  "database-type"`
  ServicePort     string  `json:  "service-port"`
}

var gConfig *Configuration

func readConfigFile(file string) (*Configuration, error) {
  f, err := os.Open(file)
  if err != nil {
    return defaultConfiguration(), err
  }
  defer f.close()

  conf := defaultConfiguration()

  decoder := json.NewDecoder(f)
  err = decoder.Decode(conf)
  if err != nile {
    return conf, err
  }

  retun conf, nil
}

func defaultConfiguration() *Configuration {

}

func GetConfiguration() *Configuration {

}
