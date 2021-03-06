package config

import (
  "encoding/json"
  "log"
  "os"
)

type Configuration struct {
  Password        string  `json:  "password"`
  DatabaseAddress string  `json:  "database-address"`
  DatabaseType    string  `json:  "database-type"`
  ServicePort     string  `json:  "service-port"`
  MinIOAddress    string  `json:  "minio-address"`
  MinIOPort       string  `json:  "minio-port"`
  AccessKeyID     string  `json:  "access-key-id"`
  SecretAccessKey string  `json:  "secret-access-key"`
}

var gConfig *Configuration

func readConfigFile(file string) (*Configuration, error) {
  f, err := os.Open(file)
  if err != nil {
    return defaultConfiguration(), err
  }
  defer f.Close()

  conf := defaultConfiguration()

  decoder := json.NewDecoder(f)
  err = decoder.Decode(conf)
  if err != nil {
    return conf, err
  }

  return conf, nil
}

func defaultConfiguration() *Configuration {
  return &Configuration {
    Password:           "",
    DatabaseAddress:    "127.0.0.1",
    DatabaseType:       "mongo",
    ServicePort:        "9015",
    MinIOAddress:       "127.0.0.1",
    MinIOPort:          "9000",
    AccessKeyID:        "ICN-ACCESSKEYID",
    SecretAccessKey:    "ICN-SECRETACCESSKEY",
  }
}

func GetConfiguration() *Configuration {
  if gConfig == nil {
    conf, err := readConfigFile("ICNconfig.json")
    if err != nil {
      log.Println("Error loading config file. Using defaults")
    }

    gConfig = conf
  }

  return gConfig
}
