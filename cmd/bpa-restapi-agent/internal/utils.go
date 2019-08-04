package utils

import(
  //"log"
  "icn/cmd/bpa-restapi-agent/internal/db"
  "icn/cmd/bpa-restapi-agent/internal/config"
  pkgerrors "github.com/pkg/errors"
)

func CheckDatabaseConnection() error {
// To Do - Implement db and config

  err := db.CreateDBClient(config.GetConfiguration().DatabaseType)
  if err != nil {
    return pkgerrors.Cause(err)
  }

  err = db.DBconn.HealthCheck()
  if err != nil {
    return pkgerrors.Cause(err)
  }

  return nil
}

func CheckInitialSettings() error {
  err := CheckDatabaseConnection()
  if err != nil {
    return pkgerrors.Cause(err)
  }

  return nil
}
