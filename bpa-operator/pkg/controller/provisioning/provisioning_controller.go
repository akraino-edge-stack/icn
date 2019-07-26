package provisioning

import (
	"context"
        "fmt"
        "bytes"
        "path/filepath"
        "os/user"


	bpav1alpha1 "github.com/bpa-operator/pkg/apis/bpa/v1alpha1"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
        "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
        "k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
        "k8s.io/client-go/tools/clientcmd"
        "k8s.io/client-go/dynamic"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	logf "sigs.k8s.io/controller-runtime/pkg/runtime/log"
	"sigs.k8s.io/controller-runtime/pkg/source"
)

var log = logf.Log.WithName("controller_provisioning")

/**
* USER ACTION REQUIRED: This is a scaffold file intended for the user to modify with their own Controller
* business logic.  Delete these comments after modifying this file.*
 */

// Add creates a new Provisioning Controller and adds it to the Manager. The Manager will set fields on the Controller
// and Start it when the Manager is Started.
func Add(mgr manager.Manager) error {
	return add(mgr, newReconciler(mgr))
}

// newReconciler returns a new reconcile.Reconciler
func newReconciler(mgr manager.Manager) reconcile.Reconciler {
	return &ReconcileProvisioning{client: mgr.GetClient(), scheme: mgr.GetScheme()}
}

// add adds a new Controller to mgr with r as the reconcile.Reconciler
func add(mgr manager.Manager, r reconcile.Reconciler) error {
	// Create a new controller
	c, err := controller.New("provisioning-controller", mgr, controller.Options{Reconciler: r})
	if err != nil {
		return err
	}

	// Watch for changes to primary resource Provisioning
	err = c.Watch(&source.Kind{Type: &bpav1alpha1.Provisioning{}}, &handler.EnqueueRequestForObject{})
	if err != nil {
		return err
	}


	return nil
}

// blank assignment to verify that ReconcileProvisioning implements reconcile.Reconciler
var _ reconcile.Reconciler = &ReconcileProvisioning{}

// ReconcileProvisioning reconciles a Provisioning object
type ReconcileProvisioning struct {
	// This client, initialized using mgr.Client() above, is a split client
	// that reads objects from the cache and writes to the apiserver
	client client.Client
	scheme *runtime.Scheme
}

// Reconcile reads that state of the cluster for a Provisioning object and makes changes based on the state read
// and what is in the Provisioning.Spec
// TODO(user): Modify this Reconcile function to implement your Controller logic.  This example creates
// a Pod as an example
// Note:
// The Controller will requeue the Request to be processed again if the returned error is non-nil or
// Result.Requeue is true, otherwise upon completion it will remove the work from the queue.
func (r *ReconcileProvisioning) Reconcile(request reconcile.Request) (reconcile.Result, error) {
	reqLogger := log.WithValues("Request.Namespace", request.Namespace, "Request.Name", request.Name)
	reqLogger.Info("Reconciling Provisioning")

	// Fetch the Provisioning instance
	provisioningInstance := &bpav1alpha1.Provisioning{}
	err := r.client.Get(context.TODO(), request.NamespacedName, provisioningInstance)
	if err != nil {
		if errors.IsNotFound(err) {
			// Request object not found, could have been deleted after reconcile request.
			// Owned objects are automatically garbage collected. For additional cleanup logic use finalizers.
			// Return and don't requeue
			return reconcile.Result{}, nil
		}
		// Error reading the object - requeue the request.
		return reconcile.Result{}, err
	}

        mastersList := provisioningInstance.Spec.Masters
        workersList := provisioningInstance.Spec.Workers
        bareMetalHostList, _ := listBareMetalHosts()

        //Iterate through mastersList and get all the mac addresses
        for _, masterMap := range mastersList {

                for _, master := range masterMap {
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, master.MACaddress)
                   if containsMac{
                      fmt.Println( master.MACaddress)
                      fmt.Printf("BareMetalHost CR %s has NIC with MAC Address %s\n", bmhCR, master.MACaddress)
                   } else {

                      fmt.Printf("Host with MAC Address %s not found\n", master.MACaddress)
                   }
             }
        }

        //Iterate through workersList and get all the mac addresses
        for _, workerMap := range workersList {

                for _, worker := range workerMap {
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, worker.MACaddress)
                   if containsMac{
                      fmt.Println( worker.MACaddress)
                      fmt.Printf("Host %s matches that macAddress\n", bmhCR)
                   }else {

                      fmt.Printf("Host with MAC Address %s not found\n", worker.MACaddress)
                   }

             }
        }



	return reconcile.Result{}, nil
}


//Function to Get List containing baremetal hosts
func listBareMetalHosts() (*unstructured.UnstructuredList, error) {

     //Get Current User and kube config file
     usr, err := user.Current()
     if err != nil {
        fmt.Println("Could not get current user\n")
        return &unstructured.UnstructuredList{}, err
     }

     kubeConfig := filepath.Join(usr.HomeDir, ".kube", "config")

     //Build Config Flags
     config, err :=  clientcmd.BuildConfigFromFlags("", kubeConfig)
     if err != nil {
        fmt.Println("Could not build config\n")
        return &unstructured.UnstructuredList{}, err
     }

    //Create Dynamic Client  for BareMetalHost CRD
    bmhDynamicClient, err := dynamic.NewForConfig(config)

    if err != nil {
       fmt.Println("Could not create dynamic client for bareMetalHosts\n")
       return &unstructured.UnstructuredList{}, err
    }

    //Create GVR representing a BareMetalHost CR
    bmhGVR := schema.GroupVersionResource{
      Group:    "metal3.io",
      Version:  "v1alpha1",
      Resource: "baremetalhosts",
    }

    //Get List containing all BareMetalHosts CRs
    bareMetalHosts, err := bmhDynamicClient.Resource(bmhGVR).List(metav1.ListOptions{})
    if err != nil {
       fmt.Println("Error occured, cannot get BareMetalHosts list\n")
       return &unstructured.UnstructuredList{}, err
    }

    return bareMetalHosts, nil
}

//Function to check if BareMetalHost containing MAC address exist
func checkMACaddress(bareMetalHostList *unstructured.UnstructuredList, macAddress string) (bool, string) {

     //Convert macAddress to byte array for comparison
     macAddressByte :=  []byte(macAddress)
     macBool := false

     for _, bareMetalHost := range bareMetalHostList.Items {
         bmhJson, _ := bareMetalHost.MarshalJSON()

         macBool = bytes.Contains(bmhJson, macAddressByte)
         if macBool{
             return macBool, bareMetalHost.GetName()
         }

      }

         return macBool, ""

}
