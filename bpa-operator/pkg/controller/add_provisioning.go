package controller

import (
	"github.com/bpa-operator/pkg/controller/provisioning"
)

func init() {
	// AddToManagerFuncs is a list of functions to create controllers and add them to a manager.
	AddToManagerFuncs = append(AddToManagerFuncs, provisioning.Add)
}
