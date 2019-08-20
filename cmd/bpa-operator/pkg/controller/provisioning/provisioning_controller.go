package provisioning

import (
	"context"
        "os"
        "fmt"
        "bytes"
	"regexp"
	"strings"
	"io/ioutil"
        "os/exec"


	bpav1alpha1 "github.com/bpa-operator/pkg/apis/bpa/v1alpha1"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
        "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
        "k8s.io/apimachinery/pkg/runtime/schema"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/runtime"
        "k8s.io/client-go/dynamic"
	"sigs.k8s.io/controller-runtime/pkg/client"
        "sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/controller"
	"sigs.k8s.io/controller-runtime/pkg/handler"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/reconcile"
	logf "sigs.k8s.io/controller-runtime/pkg/runtime/log"
	"sigs.k8s.io/controller-runtime/pkg/source"
        "gopkg.in/ini.v1"
)

var log = logf.Log.WithName("controller_provisioning")
//var dhcpLeaseFile = "/var/lib/dhcp/dhcpd.leases"
//var kudInstallerScript = "/root/icn/deploy/kud/multicloud-k8s/kud/hosting_providers/vagrant"

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
        dhcpLeaseFile := provisioningInstance.Spec.DHCPleaseFile
        kudInstallerScript := provisioningInstance.Spec.KUDInstaller
        bareMetalHostList, _ := listBareMetalHosts()


        var allString string
        var masterString string
        var workerString string



       //Iterate through mastersList and get all the mac addresses and IP addresses
       for _, masterMap := range mastersList {

                for masterLabel, master := range masterMap {
		   masterMAC := master.MACaddress

                   if masterMAC == "" {
                      err = fmt.Errorf("MAC address for masterNode %s not provided\n", masterLabel)
                      return reconcile.Result{}, err
                   }
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, masterMAC)
                   if containsMac{
                      fmt.Printf("BareMetalHost CR %s has NIC with MAC Address %s\n", bmhCR, masterMAC)

                      //Get IP address of master
                      hostIPaddress, err := getHostIPaddress(masterMAC, dhcpLeaseFile )
                      if err != nil || hostIPaddress == ""{
                        err = fmt.Errorf("IP address not found for host with MAC address %s \n", masterMAC)
                        return reconcile.Result{}, err
                      }

                      allString += masterLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                      masterString += masterLabel + "\n"

                      fmt.Printf("%s : %s \n", hostIPaddress, masterMAC)


                      if len(workersList) != 0 {

		          //Iterate through workersList and get all the mac addresses
                          for _, workerMap := range workersList {

                              //Get worker labels from the workermap
                              for workerLabel, worker := range workerMap {

                                  //Check if workerString already contains worker label
			          containsWorkerLabel := strings.Contains(workerString, workerLabel)
			          workerMAC := worker.MACaddress

                                   //Error occurs if the same label is given to different hosts (assumption, 
                                   //each MAC address represents a unique host
				   if workerLabel == masterLabel && workerMAC != masterMAC && workerMAC != "" {
				     if containsWorkerLabel {
					    strings.ReplaceAll(workerString, workerLabel, "")
					 }
				      err = fmt.Errorf(`A node with label %s already exists, modify resource and assign a 
                                      different label to node with MACAddress %s`, workerLabel, workerMAC)
				      return reconcile.Result{}, err

                                   //same node performs worker and master roles
				   } else if workerLabel == masterLabel && !containsWorkerLabel {
				        workerString += workerLabel + "\n"

                                   //Error occurs if the same node is given different labels
				   } else if workerLabel != masterLabel && workerMAC == masterMAC {
				         if containsWorkerLabel {
					    strings.ReplaceAll(workerString, workerLabel, "")
					 }
				      err = fmt.Errorf(`A node with label %s already exists, modify resource and assign a
					                different label to node with MACAddress %s`, workerLabel, workerMAC)
				      return reconcile.Result{}, err

                                   //worker node is different from any master node and it has not been added to the worker list
				   } else if workerLabel != masterLabel && !containsWorkerLabel {

                                        // Error occurs if MAC address not provided for worker node not matching master
                                        if workerMAC == "" {
                                          err = fmt.Errorf("MAC address for worker %s not provided", workerLabel)
                                          return reconcile.Result{}, err
                                         }

                                        containsMac, bmhCR := checkMACaddress(bareMetalHostList, workerMAC)
                                        if containsMac{
                                           fmt.Printf("Host %s matches that macAddress\n", bmhCR)

                                           //Get IP address of worker
                                           hostIPaddress, err := getHostIPaddress(workerMAC, dhcpLeaseFile )
                                           if err != nil {
                                              fmt.Printf("IP address not found for host with MAC address %s \n", workerMAC)
                                           }
                                           fmt.Printf("%s : %s \n", hostIPaddress, workerMAC)

                                           allString += workerLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                                           workerString += workerLabel + "\n"

                                       //No host found that matches the worker MAC
                                       } else {

                                            err = fmt.Errorf("Host with MAC Address %s not found\n", workerMAC)
                                            return reconcile.Result{}, err
                                          }
				     }

                         }
                       }
                   //No worker node specified, add master as worker node
                   } else if len(workersList) == 0 && !strings.Contains(workerString, masterLabel) {
                       workerString += masterLabel + "\n"
                   }

                   //No host matching master MAC found
                   } else {
                      err = fmt.Errorf("Host with MAC Address %s not found\n", masterMAC)
                      return reconcile.Result{}, err
                   }
             }
        }

        //Create host.ini file
        //iniHostFilePath := provisioningInstance.Spec.HostsFile
        iniHostFilePath := kudInstallerScript + "/inventory/hosts.ini"
        newFile, err := os.Create(iniHostFilePath)
        defer newFile.Close()


        if err != nil {
           fmt.Printf("Error occured while creating file \n %v", err)
           return reconcile.Result{}, err
        }

        hostFile, err := ini.Load(iniHostFilePath)
        if err != nil {
           fmt.Printf("Error occured while Loading file \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("all", allString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }
        _, err = hostFile.NewRawSection("kube-master", masterString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("kube-node", workerString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("etcd", masterString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("k8s-cluster:children", "kube-node\n" + "kube-master")
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }


        hostFile.SaveTo(iniHostFilePath)

        //TODO: Test KUD installer part
        //Copy host.ini file to the right path and install KUD
        //dstIniPath := kudInstallerScript + "/inventory/hosts.ini"
        //kudInstaller(iniHostFilePath, dstIniPath, kudInstallerScript)
        kudInstaller(kudInstallerScript)
	return reconcile.Result{}, nil
}


//Function to Get List containing baremetal hosts
func listBareMetalHosts() (*unstructured.UnstructuredList, error) {

     config, err :=  config.GetConfig()
     if err != nil {
        fmt.Println("Could not get kube config\n")
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

//func kudInstaller(srcIniPath, dstIniPath, kudInstallerPath string) {
func kudInstaller(kudInstallerPath string) {

      err := os.Chdir(kudInstallerPath)
      if err != nil {
          fmt.Printf("Could not change directory %v", err)
          return
        }

      //commands := "cp " + srcIniPath + " "  + dstIniPath + "; ./installer.sh| tee kud_installer.log"
      commands := "./installer.sh| tee kud_installer.log"

      cmd := exec.Command("/bin/bash", "-c", commands)
      err = cmd.Start()

      if err != nil {
          fmt.Printf("Error Occured while Starting KUD install scripts %v", err)
          return
        }

      return
}
