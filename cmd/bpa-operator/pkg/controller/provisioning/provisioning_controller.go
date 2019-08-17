package provisioning

import (
	"context"
        "os"
        "fmt"
        "bytes"
	"regexp"
	"strings"
	"io/ioutil"
        "path/filepath"
        "os/user"
        "os/exec"


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
        "gopkg.in/ini.v1"
)

var log = logf.Log.WithName("controller_provisioning")
//Todo: Should be an input from the user
var dhcpLeaseFile = "/var/lib/dhcp/dhcpd.leases"
var kudInstallerScript = "/root/icn/deploy/kud/multicloud-k8s/kud/hosting_providers/vagrant"

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


        var allString string
        var masterString string
        var workerString string

       //Iterate through mastersList and get all the mac addresses and IP addresses

        for _, masterMap := range mastersList {

                for masterLabel, master := range masterMap {
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, master.MACaddress)
                   if containsMac{
                      //fmt.Println( master.MACaddress)
                      fmt.Printf("BareMetalHost CR %s has NIC with MAC Address %s\n", bmhCR, master.MACaddress)

                      //Get IP address of master
                      hostIPaddress, err := getHostIPaddress(master.MACaddress, dhcpLeaseFile )
                     if err != nil {
                        fmt.Printf("IP address not found for host with MAC address %s \n", master.MACaddress)
                     }



                      allString += masterLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                      masterString += masterLabel + "\n"

                      fmt.Printf("%s : %s \n", hostIPaddress, master.MACaddress)



                   } else {

                      fmt.Printf("Host with MAC Address %s not found\n", master.MACaddress)
                   }
             }
        }


        //Iterate through workersList and get all the mac addresses
        for _, workerMap := range workersList {

                for workerLabel, worker := range workerMap {
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, worker.MACaddress)
                   if containsMac{
                      //fmt.Println( worker.MACaddress)
                      fmt.Printf("Host %s matches that macAddress\n", bmhCR)

                      //Get IP address of worker
                      hostIPaddress, err := getHostIPaddress(worker.MACaddress, dhcpLeaseFile )
                     if err != nil {
                        fmt.Printf("IP address not found for host with MAC address %s \n", worker.MACaddress)
                     }
                      fmt.Printf("%s : %s \n", hostIPaddress, worker.MACaddress)

                      allString += workerLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                      workerString += workerLabel + "\n"

                   }else {

                      fmt.Printf("Host with MAC Address %s not found\n", worker.MACaddress)
                   }

             }
        }


        //Create host.ini file
        iniHostFilePath := provisioningInstance.Spec.HostsFile
        newFile, err := os.Create(iniHostFilePath)
        defer newFile.Close()


        if err != nil {
           fmt.Printf("Error occured while creating file \n %v", err)
        }

        hostFile, err := ini.Load(iniHostFilePath)
        if err != nil {
           fmt.Printf("Error occured while Loading file \n %v", err)
        }

        _, err = hostFile.NewRawSection("all", allString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
        }
        _, err = hostFile.NewRawSection("kube-master", masterString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
        }

        _, err = hostFile.NewRawSection("kube-node", workerString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
        }

        _, err = hostFile.NewRawSection("etcd", masterString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
        }

        _, err = hostFile.NewRawSection("k8s-cluser:children", "kube-node\n" + "kube-master")
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
        }


        hostFile.SaveTo(iniHostFilePath)

       //TODO: Test KUD installer part
       //Copy host.ini file to the right path and install KUD
       dstIniPath := kudInstallerScript + "/inventory/hosts.ini"
       kudInstaller(iniHostFilePath, dstIniPath, kudInstallerScript)

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

func getHostIPaddress(macAddress string, dhcpLeaseFilePath string ) (string, error) {

     //Read the dhcp lease file
     dhcpFile, err := ioutil.ReadFile(dhcpLeaseFilePath)
     if err != nil {
        fmt.Println("Failed to read lease file\n")
        return "", err
     }

     dhcpLeases := string(dhcpFile)

     //Regex to use to search dhcpLeases
     regex := "lease.*{|ethernet.*"
     re, err := regexp.Compile(regex)
     if err != nil {
        fmt.Println("Could not create Regexp object\n")
        return "", err
     }

     //Get String containing leased Ip addresses and Corressponding MAC addresses
     out := re.FindAllString(dhcpLeases, -1)
     outString := strings.Join(out, " ")
     stringReplacer := strings.NewReplacer("lease", "", "{ ethernet ", "", ";", "")
     replaced := stringReplacer.Replace(outString)
     ipMacList := strings.Fields(replaced)


     //Get IP addresses corresponding to Input MAC Address
     for idx := len(ipMacList)-1 ; idx >= 0; idx -- {
         item := ipMacList[idx]
         if item == macAddress  {
            ipAdd := ipMacList[idx -1]
            return ipAdd, nil
    }

 }
     return "", nil
}

func kudInstaller(srcIniPath, dstIniPath, kudInstallerPath string) {

      err := os.Chdir(kudInstallerPath)
      if err != nil {
          fmt.Printf("Could not change directory %v", err)
          return
        }

      commands := "cp " + srcIniPath + " "  + dstIniPath + "; ./installer.sh| tee kud_installer.log"

      cmd := exec.Command("/bin/bash", "-c", commands)
      err = cmd.Run()

      if err != nil {
          fmt.Printf("Error Occured while running KUD install scripts %v", err)
          return
        }

      return
}
