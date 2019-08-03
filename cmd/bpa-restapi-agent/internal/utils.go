package utils

import(
  "log"
  "db"
  "config"
  pkgerrors "github.com/pkg/errors"
)

func CheckDatabaseConnection() error {
// To Do - Implement db and config

  err := db.CreateDBCLient(config.GetConfiguration().DatabaseType)
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
  error := CheckDatabaseConnection()
  if err != nil {
    return pkgerrors.Cause(err)
  }
}
