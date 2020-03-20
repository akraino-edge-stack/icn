package provisioning

import (
        "context"
        "os"
        "fmt"
        "time"
        "bytes"
        "regexp"
        "strings"
        "io/ioutil"
        "encoding/json"

        bpav1alpha1 "github.com/bpa-operator/pkg/apis/bpa/v1alpha1"
        metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
        corev1 "k8s.io/api/core/v1"
        batchv1 "k8s.io/api/batch/v1"
        "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
        "k8s.io/apimachinery/pkg/runtime/schema"
        "k8s.io/apimachinery/pkg/api/errors"
        "k8s.io/apimachinery/pkg/runtime"
        "k8s.io/apimachinery/pkg/types"
        "k8s.io/client-go/dynamic"

        "sigs.k8s.io/controller-runtime/pkg/client"
        "sigs.k8s.io/controller-runtime/pkg/client/config"
        "sigs.k8s.io/controller-runtime/pkg/controller"
        "sigs.k8s.io/controller-runtime/pkg/controller/controllerutil"
        "sigs.k8s.io/controller-runtime/pkg/handler"
        "sigs.k8s.io/controller-runtime/pkg/manager"
        "sigs.k8s.io/controller-runtime/pkg/reconcile"
        logf "sigs.k8s.io/controller-runtime/pkg/runtime/log"
        "sigs.k8s.io/controller-runtime/pkg/source"
        "gopkg.in/ini.v1"
	"golang.org/x/crypto/ssh"
)

type VirtletVM struct {
        IPaddress string
        MACaddress string
}

type NetworksStatus struct {
        Name string `json:"name,omitempty"`
        Interface string `json:"interface,omitempty"`
        Ips []string `json:"ips,omitempty"`
        Mac string `json:"mac,omitempty"`
        Default bool `json:"default,omitempty"`
        Dns interface{} `json:"dns,omitempty"`
}

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

        config, err :=  config.GetConfig()
        if err != nil {
           fmt.Printf("Could not get kube config, Error: %v\n", err)
        }

       bmhDynamicClient, err := dynamic.NewForConfig(config)

       if err != nil {
          fmt.Printf("Could not create dynamic client for bareMetalHosts, Error: %v\n", err)
       }

       return &ReconcileProvisioning{client: mgr.GetClient(), scheme: mgr.GetScheme(), bmhClient: bmhDynamicClient }
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

	// Watch for changes to resource configmap created as a consequence of the provisioning CR
	err = c.Watch(&source.Kind{Type: &corev1.ConfigMap{}}, &handler.EnqueueRequestForOwner{
                IsController: true,
                OwnerType:   &bpav1alpha1.Provisioning{},
        })

        if err != nil {
                return err
        }

       //Watch for changes to job resource also created as a consequence of the provisioning CR
       err = c.Watch(&source.Kind{Type: &batchv1.Job{}}, &handler.EnqueueRequestForOwner{
                IsController: true,
                OwnerType:   &bpav1alpha1.Provisioning{},
        })

        if err != nil {
                return err
        }

        // Watch for changes to resource software CR
        err = c.Watch(&source.Kind{Type: &bpav1alpha1.Software{}}, &handler.EnqueueRequestForObject{})
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
        bmhClient dynamic.Interface
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
        fmt.Printf("\n\n")
        reqLogger.Info("Reconciling Custom Resource")



        // Fetch the Provisioning instance
        provisioningInstance := &bpav1alpha1.Provisioning{}
        softwareInstance := &bpav1alpha1.Software{}
        err := r.client.Get(context.TODO(), request.NamespacedName, provisioningInstance)
        provisioningCreated := true
        if err != nil {

                         //Check if its a Software Instance
                         err = r.client.Get(context.TODO(), request.NamespacedName, softwareInstance)
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

                         //No error occured and so a Software CR was created not a Provisoning CR
                         provisioningCreated = false
        }


        masterTag := "MASTER_"
        workerTag := "WORKER_"

        if provisioningCreated {

        ///////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////         Provisioning CR was created so install KUD          /////////////////
        //////////////////////////////////////////////////////////////////////////////////////////////
        provisioningVersion := provisioningInstance.ResourceVersion
	clusterName := provisioningInstance.Labels["cluster"]
	clusterType := provisioningInstance.Labels["cluster-type"]
        mastersList := provisioningInstance.Spec.Masters
        workersList := provisioningInstance.Spec.Workers


        bareMetalHostList, _ := listBareMetalHosts(r.bmhClient)
        virtletVMList, _ := listVirtletVMs(r.client)



        var allString string
        var masterString string
        var workerString string

	dhcpLeaseFile := "/var/lib/dhcp/dhcpd.leases"
	multiClusterDir := "/multi-cluster"

	//Create Directory for the specific cluster
	clusterDir := multiClusterDir + "/" + clusterName
	os.MkdirAll(clusterDir, os.ModePerm)

	//Create Maps to be used for cluster ip address to label configmap
	clusterData := make(map[string]string)
	clusterMACData := make(map[string]string)



       //Iterate through mastersList and get all the mac addresses and IP addresses
       for _, masterMap := range mastersList {

                for masterLabel, master := range masterMap {
                   masterMAC := master.MACaddress
                   hostIPaddress := ""

                   if masterMAC == "" {
                      err = fmt.Errorf("MAC address for masterNode %s not provided\n", masterLabel)
                      return reconcile.Result{}, err
                   }


                   // Check if master MAC address has already been used
                   usedMAC, err := r.macAddressUsed(provisioningInstance.Namespace, masterMAC, clusterName)


                   if err != nil {

                      fmt.Printf("Error occured while checking if mac Address has already been used\n %v", err)
                      return reconcile.Result{}, err
                   }

                   if usedMAC {

                      err = fmt.Errorf("MAC address %s has already been used, check and update provisioning CR", masterMAC)
                      return reconcile.Result{}, err

                   }

                   // Check if Baremetal host with specified MAC address exist
                   containsMac, bmhCR := checkMACaddress(bareMetalHostList, masterMAC)

		   //Check 'cluster-type' label for Virtlet VMs
		   if clusterType == "virtlet-vm" {
                       //Get VM IP address of master
                       hostIPaddress, err = getVMIPaddress(virtletVMList, masterMAC)
                       if err != nil || hostIPaddress == "" {
                           err = fmt.Errorf("IP address not found for VM with MAC address %s \n", masterMAC)
                           return reconcile.Result{}, err
                       }
                       containsMac = true
		   }

                   if containsMac {

		       if clusterType != "virtlet-vm" {
                           fmt.Printf("BareMetalHost CR %s has NIC with MAC Address %s\n", bmhCR, masterMAC)

                           //Get IP address of master
                           hostIPaddress, err = getHostIPaddress(masterMAC, dhcpLeaseFile )
                           if err != nil || hostIPaddress == ""{
                               err = fmt.Errorf("IP address not found for host with MAC address %s \n", masterMAC)
                               return reconcile.Result{}, err
                           }
		       }

                       allString += masterLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                       if clusterType == "virtlet-vm" {
                           allString = masterLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + " ansible_ssh_user=root" + " ansible_ssh_pass=root" + "\n"
                       }
                       masterString += masterLabel + "\n"
                       clusterData[masterTag + masterLabel] = hostIPaddress
                       clusterMACData[strings.ReplaceAll(masterMAC, ":", "-")] = masterTag + masterLabel

                       fmt.Printf("%s : %s \n", hostIPaddress, masterMAC)


                       // Check if any worker MAC address was specified
                       if len(workersList) != 0 {

                           //Iterate through workersList and get all the mac addresses
                           for _, workerMap := range workersList {

                               //Get worker labels from the workermap
                               for workerLabel, worker := range workerMap {

                                   //Check if workerString already contains worker label
                                   containsWorkerLabel := strings.Contains(workerString, workerLabel)
                                   workerMAC := worker.MACaddress
                                   hostIPaddress = ""

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

                                        //Add host to ip address config map with worker tag
                                        hostIPaddress = clusterData[masterTag + masterLabel]
                                        clusterData[workerTag + masterLabel] = hostIPaddress

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

                                        // Check if worker MAC address has already been used
                                        usedMAC, err = r.macAddressUsed(provisioningInstance.Namespace, workerMAC, clusterName)

                                        if err != nil {

                                           fmt.Printf("Error occured while checking if mac Address has already been used\n %v", err)
                                           return reconcile.Result{}, err
                                        }

                                        if usedMAC {

                                           err = fmt.Errorf("MAC address %s has already been used, check and update provisioning CR", workerMAC)
                                           return reconcile.Result{}, err

                                        }

                                        containsMac, bmhCR := checkMACaddress(bareMetalHostList, workerMAC)

					if clusterType == "virtlet-vm" {
		                            //Get VM IP address of master
		                            hostIPaddress, err = getVMIPaddress(virtletVMList, workerMAC)
		                            if err != nil || hostIPaddress == "" {
		                                err = fmt.Errorf("IP address not found for VM with MAC address %s \n", workerMAC)
		                                return reconcile.Result{}, err
		                            }
		                            containsMac = true
		                        }

                                        if containsMac{

		                           if clusterType != "virtlet-vm" {
                                               fmt.Printf("Host %s matches that macAddress\n", bmhCR)

                                               //Get IP address of worker
                                               hostIPaddress, err = getHostIPaddress(workerMAC, dhcpLeaseFile )
                                               if err != nil {
                                                   fmt.Errorf("IP address not found for host with MAC address %s \n", workerMAC)
                                                   return reconcile.Result{}, err
                                               }
					   }
                                           fmt.Printf("%s : %s \n", hostIPaddress, workerMAC)

                                           allString += workerLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + "\n"
                                           if clusterType == "virtlet-vm" {
                                               allString = masterLabel + "  ansible_ssh_host="  + hostIPaddress + " ansible_ssh_port=22" + " ansible_ssh_user=root" + " ansible_ssh_pass=root" + "\n"
                                           }
                                           workerString += workerLabel + "\n"
					   clusterData[workerTag + workerLabel] = hostIPaddress
					   clusterMACData[strings.ReplaceAll(workerMAC, ":", "-")] = workerTag + workerLabel

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

                       //Add host to ip address config map with worker tag
                       hostIPaddress = clusterData[masterTag + masterLabel]
                       clusterData[workerTag + masterLabel] = hostIPaddress
                   }

                   //No host matching master MAC found
                   } else {
                      err = fmt.Errorf("Host with MAC Address %s not found\n", masterMAC)
                      return reconcile.Result{}, err
                   }
             }
        }

        //Create host.ini file
        iniHostFilePath := clusterDir + "/hosts.ini"
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

        _, err = hostFile.NewRawSection("ovn-central", masterString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("ovn-controller", workerString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("virtlet", workerString)
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }

        _, err = hostFile.NewRawSection("k8s-cluster:children", "kube-node\n" + "kube-master")
        if err != nil {
           fmt.Printf("Error occured while creating section \n %v", err)
           return reconcile.Result{}, err
        }


	//Create host.ini file for KUD
        hostFile.SaveTo(iniHostFilePath)

        // Create configmap to store MAC address info for the cluster
        cmName := provisioningInstance.Labels["cluster"] + "-mac-addresses"
        foundConfig := &corev1.ConfigMap{}
        err = r.client.Get(context.TODO(), types.NamespacedName{Name: cmName, Namespace: provisioningInstance.Namespace}, foundConfig)

        // Configmap was found but the provisioning CR was updated so update configMap
        if err == nil && foundConfig.Labels["provisioning-version"] != provisioningVersion {

           foundConfig.Data = clusterMACData
           foundConfig.Labels =  provisioningInstance.Labels
           foundConfig.Labels["configmap-type"] = "mac-address"
           foundConfig.Labels["provisioning-version"] = provisioningVersion
           err = r.client.Update(context.TODO(), foundConfig)
           if err != nil {
              fmt.Printf("Error occured while updating mac address configmap for provisioningCR %s\n ERROR: %v\n", provisioningInstance.Name,
              err)
              return reconcile.Result{}, err
           }

        }  else if err != nil && errors.IsNotFound(err) {
           labels :=  provisioningInstance.Labels
           labels["configmap-type"] = "mac-address"
           labels["provisioning-version"] = provisioningVersion
           err = r.createConfigMap(provisioningInstance, clusterMACData, labels, cmName)
           if err != nil {
              fmt.Printf("Error occured while creating MAC address configmap for cluster %v\n ERROR: %v", clusterName, err)
              return reconcile.Result{}, err
            }

        } else if err != nil {
            fmt.Printf("ERROR occured in Create MAC address Config map section: %v\n", err)
            return reconcile.Result{}, err
          }

        //Install KUD
        err = r.createKUDinstallerJob(provisioningInstance)
        if err != nil {
           fmt.Printf("Error occured while creating KUD Installer job for cluster %v\n ERROR: %v", clusterName, err)
           return reconcile.Result{}, err
        }

        //Start separate thread to keep checking job status, Create an IP address configmap
        //for cluster if KUD is successfully installed
        go r.checkJob(provisioningInstance, clusterData)

        return reconcile.Result{}, nil

       }



        ///////////////////////////////////////////////////////////////////////////////////////////////
        ////////////////         Software CR was created so install software         /////////////////
        //////////////////////////////////////////////////////////////////////////////////////////////
        softwareClusterName, masterSoftwareList, workerSoftwareList := getSoftwareList(softwareInstance)
        defaultSSHPrivateKey := "/root/.ssh/id_rsa"

        //Get IP address configmap for the cluster
        configmapName :=  softwareInstance.Labels["cluster"] + "-configmap"
        clusterConfigMapData, err := r.getConfigMapData(softwareInstance.Namespace, configmapName)
        if err != nil {
           fmt.Printf("Error occured while retrieving IP address Data for cluster %s, ERROR: %v\n", softwareClusterName, err)
           return reconcile.Result{}, err
        }

        for hostLabel, ipAddress := range clusterConfigMapData {

            if strings.Contains(hostLabel, masterTag) {
               // Its a master node, install master software
               err = softwareInstaller(ipAddress, defaultSSHPrivateKey, masterSoftwareList)
               if err != nil {
                  fmt.Printf("Error occured while installing master software in host %s, ERROR: %v\n", hostLabel, err)
               }
            } else if strings.Contains(hostLabel, workerTag) {
              // Its a worker node, install worker software
              err = softwareInstaller(ipAddress, defaultSSHPrivateKey, workerSoftwareList)
              if err != nil {
                  fmt.Printf("Error occured while installing worker software in host %s, ERROR: %v\n", hostLabel, err)
               }

            }

        }

        return reconcile.Result{}, nil
}

//Function to Get List containing baremetal hosts
func listBareMetalHosts(bmhDynamicClient dynamic.Interface) (*unstructured.UnstructuredList, error) {

    //Create GVR representing a BareMetalHost CR
    bmhGVR := schema.GroupVersionResource{
      Group:    "metal3.io",
      Version:  "v1alpha1",
      Resource: "baremetalhosts",
    }

    //Get List containing all BareMetalHosts CRs
    bareMetalHosts, err := bmhDynamicClient.Resource(bmhGVR).List(metav1.ListOptions{})
    if err != nil {
       fmt.Printf("Error occured, cannot get BareMetalHosts list, Error: %v\n", err)
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

//Function to check if MAC address has been used in another provisioning CR
//Returns true if MAC address has already been used
func (r *ReconcileProvisioning) macAddressUsed(namespace, macAddress, provisioningCluster string) (bool, error) {

     macKey := strings.ReplaceAll(macAddress, ":", "-")

     //Get configmap List
     cmList := &corev1.ConfigMapList{}
     label := map[string]string{"configmap-type": "mac-address"}
     listOpts :=  client.MatchingLabels(label)

     err := r.client.List(context.TODO(), listOpts, cmList)
     if err != nil {
        return false, err
     }

     for _, configmap := range cmList.Items {

        cmCluster := configmap.Labels["cluster"]
        if cmCluster != provisioningCluster {
            cmData, err := r.getConfigMapData(namespace, configmap.Name)
            if err != nil {
               return false, err

            }

            if _, exist := cmData[macKey]; exist {

               return exist, nil
            }
       }

     }

     return false, nil

}



//Function to get the IP address of a host from the DHCP file
func getHostIPaddress(macAddress string, dhcpLeaseFilePath string ) (string, error) {

     //Read the dhcp lease file
     dhcpFile, err := ioutil.ReadFile(dhcpLeaseFilePath)
     if err != nil {
        fmt.Printf("Failed to read lease file\n")
        return "", err
     }

     dhcpLeases := string(dhcpFile)

     //Regex to use to search dhcpLeases
     reg := "lease.*{|ethernet.*|\n. binding state.*"
     re, err := regexp.Compile(reg)
     if err != nil {
        fmt.Printf("Could not create Regexp object, Error %v occured\n", err)
        return "", err
     }

     //Get String containing leased Ip addresses and Corressponding MAC addresses
     out := re.FindAllString(dhcpLeases, -1)
     outString := strings.Join(out, " ")
     stringReplacer := strings.NewReplacer("lease", "", "ethernet ", "", ";", "",
     " binding state", "", "{", "")
     replaced := stringReplacer.Replace(outString)
     ipMacList := strings.Fields(replaced)


     //Get IP addresses corresponding to Input MAC Address
     for idx := len(ipMacList)-1 ; idx >= 0; idx -- {
         item := ipMacList[idx]
         if item == macAddress  {

            leaseState := ipMacList[idx -1]
            if leaseState != "active" {
               err := fmt.Errorf("No active ip address lease found for MAC address %s \n", macAddress)
               fmt.Printf("%v\n", err)
               return "", err
            }
            ipAdd := ipMacList[idx - 2]
            return ipAdd, nil
    }

 }
     return "", nil
}

//Function to create configmap
func (r *ReconcileProvisioning) createConfigMap(p *bpav1alpha1.Provisioning, data, labels map[string]string, cmName string) error{

         // Configmap has not been created, create it
          configmap := &corev1.ConfigMap{

              ObjectMeta: metav1.ObjectMeta{
                        Name: cmName,
			Namespace: p.Namespace,
                        Labels: labels,
                      },
              Data: data,
          }


         // Set provisioning instance as the owner of the job
         controllerutil.SetControllerReference(p, configmap, r.scheme)
         err := r.client.Create(context.TODO(), configmap)
         if err != nil {
             return err

         }

     return nil

}

//Function to get configmap Data
func (r *ReconcileProvisioning) getConfigMapData(namespace, configmapName string) (map[string]string, error) {

     clusterConfigmap := &corev1.ConfigMap{}
     err := r.client.Get(context.TODO(), types.NamespacedName{Name: configmapName, Namespace: namespace}, clusterConfigmap)
     if err != nil {
        return nil, err
     }

     configmapData := clusterConfigmap.Data
     return configmapData, nil
}

//Function to create job for KUD installation
func (r *ReconcileProvisioning) createKUDinstallerJob(p *bpav1alpha1.Provisioning) error{

    var backOffLimit int32 = 0
    var privi bool = true


    kudPlugins := p.Spec.KUDPlugins

    jobLabel := p.Labels
    jobLabel["provisioning-version"] = p.ResourceVersion
    jobName := "kud-" + jobLabel["cluster"]

    // Check if the job already exist
    foundJob := &batchv1.Job{}
    err := r.client.Get(context.TODO(), types.NamespacedName{Name: jobName, Namespace: p.Namespace}, foundJob)

    if (err == nil && foundJob.Labels["provisioning-version"] != jobLabel["provisioning-version"]) || (err != nil && errors.IsNotFound(err)) {

       // If err == nil and its in this statement, then provisioning CR was updated, delete job
       if err == nil {
          err = r.client.Delete(context.TODO(), foundJob, client.PropagationPolicy(metav1.DeletePropagationForeground))
          if err != nil {
             fmt.Printf("Error occured while deleting kud install job for updated provisioning CR %v\n", err)
             return err
          }
       }

       // Job has not been created, create a new kud job
       installerString := " ./installer --cluster " + p.Labels["cluster"]

       // Check if any plugin was specified
       if len(kudPlugins) > 0 {
	    plugins := " --plugins"

	    for _, plug := range kudPlugins {
	        plugins += " " + plug
	    }

	   installerString += plugins
       }

       // Define new job
       job := &batchv1.Job{

        ObjectMeta: metav1.ObjectMeta{
                       Name: jobName,
                       Namespace: p.Namespace,
                       Labels: jobLabel,
                },
                Spec: batchv1.JobSpec{
                      Template: corev1.PodTemplateSpec{
                                ObjectMeta: metav1.ObjectMeta{
                                        Labels: p.Labels,
                                },


                        Spec: corev1.PodSpec{
                              HostNetwork: true,
                              Containers: []corev1.Container{{
                                          Name: "kud",
                                          Image: "github.com/onap/multicloud-k8s:latest",
                                          ImagePullPolicy: "IfNotPresent",
                                          VolumeMounts: []corev1.VolumeMount{{
                                                        Name: "multi-cluster",
                                                        MountPath: "/opt/kud/multi-cluster",
                                                        },
                                                        {
                                                        Name: "secret-volume",
                                                        MountPath: "/.ssh",
                                                        },

                                           },
                                           Command: []string{"/bin/sh","-c"},
                                           Args: []string{"cp -r /.ssh /root/; chmod -R 600 /root/.ssh;" + installerString},
                                           SecurityContext: &corev1.SecurityContext{
                                                            Privileged : &privi,

                                           },
                                          },
                                 },
                                 Volumes: []corev1.Volume{{
                                          Name: "multi-cluster",
                                          VolumeSource: corev1.VolumeSource{
                                                       HostPath: &corev1.HostPathVolumeSource{
                                                              Path : "/opt/kud/multi-cluster",
                                                     }}},
                                          {
                                          Name: "secret-volume",
                                          VolumeSource: corev1.VolumeSource{
                                                        Secret: &corev1.SecretVolumeSource{
                                                              SecretName: "ssh-key-secret",
                                                        },

                                          }}},
                                 RestartPolicy: "Never",
                              },

                             },
                             BackoffLimit : &backOffLimit,
                             },

       }

       // Set provisioning instance as the owner and controller of the job
       controllerutil.SetControllerReference(p, job, r.scheme)
       err = r.client.Create(context.TODO(), job)
       if err != nil {
          fmt.Printf("ERROR occured while creating job to install KUD\n ERROR:%v", err)
          return err
          }

    } else if err != nil {
         return err
    }

   return nil

}


//Function to Check if job succeeded
func (r *ReconcileProvisioning) checkJob(p *bpav1alpha1.Provisioning, data map[string]string) {

     clusterName := p.Labels["cluster"]
     fmt.Printf("\nChecking job status for cluster %s\n", clusterName)
     jobName := "kud-" + clusterName
     job := &batchv1.Job{}

     for {

         err := r.client.Get(context.TODO(), types.NamespacedName{Name: jobName, Namespace: p.Namespace}, job)
         if err != nil {
            fmt.Printf("ERROR: %v occured while retrieving job: %s", err, jobName)
            return
         }
         jobSucceeded := job.Status.Succeeded
         jobFailed := job.Status.Failed

         if jobSucceeded == 1 {
            fmt.Printf("\n Job succeeded, KUD successfully installed in Cluster %s\n", clusterName)

            //KUD was installed successfully create configmap to store IP address info for the cluster
            labels := p.Labels
            labels["provisioning-version"] = p.ResourceVersion
            cmName := labels["cluster"] + "-configmap"
            foundConfig := &corev1.ConfigMap{}
            err := r.client.Get(context.TODO(), types.NamespacedName{Name: cmName, Namespace: p.Namespace}, foundConfig)

            // Check if provisioning CR was updated
            if err == nil && foundConfig.Labels["provisioning-version"] != labels["provisioning-version"] {

               foundConfig.Data = data
               foundConfig.Labels =  labels
               err = r.client.Update(context.TODO(), foundConfig)
               if err != nil {
                  fmt.Printf("Error occured while updating IP address configmap for provisioningCR %s\n ERROR: %v\n", p.Name, err)
                  return
                }

            } else if err != nil && errors.IsNotFound(err) {
               err = r.createConfigMap(p, data, labels, cmName)
               if err != nil {
                  fmt.Printf("Error occured while creating IP address configmap for cluster %v\n ERROR: %v", clusterName, err)
                  return
               }
               return

            } else if err != nil {
              fmt.Printf("ERROR occured while checking if IP address configmap %v already exists: %v\n", cmName, err)
              return
              }


           return
         }

        if jobFailed == 1 {
           fmt.Printf("\n Job Failed, KUD not installed in Cluster %s, check pod logs\n", clusterName)

           return
        }

        time.Sleep(5 * time.Second)
     }
    return

}
//Function to get software list from software CR
func getSoftwareList(softwareCR *bpav1alpha1.Software) (string, []interface{}, []interface{}) {

     CRclusterName := softwareCR.GetLabels()["cluster"]

     masterSofwareList := softwareCR.Spec.MasterSoftware
     workerSoftwareList := softwareCR.Spec.WorkerSoftware

     return CRclusterName, masterSofwareList, workerSoftwareList
}

//Function to install software in clusterHosts
func softwareInstaller(ipAddress, sshPrivateKey string, softwareList []interface{}) error {

     var installString string
     for _, software := range softwareList {

        switch t := software.(type){
        case string:
             installString += software.(string) + " "
        case interface{}:
             softwareMap, errBool := software.(map[string]interface{})
             if !errBool {
                fmt.Printf("Error occured, cannot install software %v\n", software)
             }
             for softwareName, versionMap := range softwareMap {

                 versionMAP, _ := versionMap.(map[string]interface{})
                 version := versionMAP["version"].(string)
                 installString += softwareName + "=" + version + " "
             }
        default:
            fmt.Printf("invalid format %v\n", t)
        }

     }

     err := sshInstaller(installString, sshPrivateKey, ipAddress)
     if err != nil {
        return err
     }
     return nil

}

//Function to Run Installation commands via ssh
func sshInstaller(softwareString, sshPrivateKey, ipAddress string) error {

     buffer, err := ioutil.ReadFile(sshPrivateKey)
     if err != nil {
        return err
     }

     key, err := ssh.ParsePrivateKey(buffer)
     if err != nil {
        return err
     }

     sshConfig := &ssh.ClientConfig{
        User: "root",
        Auth: []ssh.AuthMethod{
              ssh.PublicKeys(key),
     },

     HostKeyCallback: ssh.InsecureIgnoreHostKey(),
     }

    client, err := ssh.Dial("tcp", ipAddress + ":22", sshConfig)
    if err != nil {
       return err
    }

    session, err := client.NewSession()
    if err != nil {
       return err
    }

    defer session.Close()
    defer client.Close()

    cmd := "sudo apt-get update && apt-get install " + softwareString + "-y"
    err = session.Start(cmd)

    if err != nil {
       return err
    }

    return nil

}


// List virtlet VMs
func listVirtletVMs(vmClient client.Client) ([]VirtletVM, error) {

        var vmPodList []VirtletVM

        pods := &corev1.PodList{}
        err := vmClient.List(context.TODO(), &client.ListOptions{}, pods)
        if err != nil {
                fmt.Printf("Could not get pod info, Error: %v\n", err)
                return []VirtletVM{}, err
        }

        for _, pod := range pods.Items {
                var podAnnotation map[string]interface{}
                var podStatus corev1.PodStatus
                var podDefaultNetStatus []NetworksStatus

                annotation, err := json.Marshal(pod.ObjectMeta.GetAnnotations())
                if err != nil {
                        fmt.Printf("Could not get pod annotations, Error: %v\n", err)
                        return []VirtletVM{}, err
                }

                json.Unmarshal([]byte(annotation), &podAnnotation)
                if podAnnotation != nil && podAnnotation["kubernetes.io/target-runtime"] != nil {
                        runtime := podAnnotation["kubernetes.io/target-runtime"].(string)

                        podStatusJson, _ := json.Marshal(pod.Status)
                        json.Unmarshal([]byte(podStatusJson), &podStatus)

                        if runtime  == "virtlet.cloud" && podStatus.Phase == "Running" && podAnnotation["k8s.v1.cni.cncf.io/networks-status"] != nil {
                                ns := podAnnotation["k8s.v1.cni.cncf.io/networks-status"].(string)
                                json.Unmarshal([]byte(ns), &podDefaultNetStatus)

                                vmPodList = append(vmPodList, VirtletVM{podStatus.PodIP, podDefaultNetStatus[0].Mac})
                        }
                }
        }

        return vmPodList, nil
}

func getVMIPaddress(vmList []VirtletVM, macAddress string) (string, error) {

        for i := 0; i < len(vmList); i++ {
                if vmList[i].MACaddress == macAddress {
                        return vmList[i].IPaddress, nil
                }
        }
        return "", nil
}
