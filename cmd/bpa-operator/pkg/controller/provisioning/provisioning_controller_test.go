package provisioning

import (

       "context"
       "testing"
       "io/ioutil"
       "os"

       bpav1alpha1 "github.com/bpa-operator/pkg/apis/bpa/v1alpha1"
       metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
       batchv1 "k8s.io/api/batch/v1"
       logf "sigs.k8s.io/controller-runtime/pkg/runtime/log"
       "k8s.io/apimachinery/pkg/runtime"
       "k8s.io/apimachinery/pkg/types"
       "k8s.io/client-go/kubernetes/scheme"
       "k8s.io/apimachinery/pkg/apis/meta/v1/unstructured"
       "sigs.k8s.io/controller-runtime/pkg/client/fake"
       "sigs.k8s.io/controller-runtime/pkg/reconcile"
       fakedynamic "k8s.io/client-go/dynamic/fake"
)

func TestProvisioningController(t *testing.T) {

     logf.SetLogger(logf.ZapLogger(true))
     bpaName1 := "bpa-test-cr"
     bpaName2 := "bpa-test-2"
     bpaName3 := "bpa-test-3"
     namespace := "default"
     clusterName := "test-cluster"
     clusterName2 :=  "test-cluster-2"
     clusterName3 := "test-cluster-3"
     macAddress1 := "08:00:27:00:ab:2c"
     macAddress2 := "08:00:27:00:ab:3d"
     macAddress3 := "08:00:27:00:ab:1c"

     // Create Fake DHCP file
     err := createFakeDHCP()
     if err != nil {
        t.Fatalf("Cannot create Fake DHCP file for testing\n")
     }

     // Create Fake baremetalhost
     bmhList := newBMList()

    // Create Fake Provisioning CR
    provisioning := newBPA(bpaName1, namespace, clusterName, macAddress1)
    provisioning2 := newBPA(bpaName2, namespace, clusterName2, macAddress2)
    provisioning3 := newBPA(bpaName3, namespace, clusterName3, macAddress3)

    // Objects to track in the fake Client
    objs := []runtime.Object{provisioning, provisioning2, provisioning3}

    // Register operator types with the runtime scheme
    sc := scheme.Scheme

    sc.AddKnownTypes(bpav1alpha1.SchemeGroupVersion, provisioning, provisioning2, provisioning3)

    // Create Fake Clients
    fakeClient := fake.NewFakeClient(objs...)
    fakeDyn := fakedynamic.NewSimpleDynamicClient(sc, bmhList,)

    r := &ReconcileProvisioning{client: fakeClient, scheme: sc, bmhClient: fakeDyn}

    // Mock request to simulate Reconcile() being called on an event for a watched resource 
    req := simulateRequest(provisioning)
    _, err = r.Reconcile(req)
    if err != nil {
       t.Fatalf("reconcile: (%v)", err)
    }

   // Test 1: Check the job was created with the expected name
    job := &batchv1.Job{}
    err = r.client.Get(context.TODO(), types.NamespacedName{Name: "kud-test-cluster", Namespace: namespace}, job)
    if err != nil {
        t.Fatalf("Error occured while getting job: (%v)", err)
    }

   // Test 2: Check that cluster name metadata in job is the expected cluster name
   jobClusterName := job.Labels["cluster"]
   if jobClusterName != clusterName {
      t.Fatalf("Job cluster Name is wrong")
   }


   // Test 3: Check that the right error is produced when host with MAC address does not exist
   req = simulateRequest(provisioning2)
    _, err = r.Reconcile(req)
    expectedErr := "Host with MAC Address " + macAddress2 + " not found\n"
    if err.Error() != expectedErr {
       t.Fatalf("Failed, Unexpected error occured %v\n", err)
    }

   // Test 4: Check that the right error is produced when MAC address is not found in the DHCP lease file
   req = simulateRequest(provisioning3)
    _, err = r.Reconcile(req)
    expectedErr = "IP address not found for host with MAC address " + macAddress3 + " \n"
    if err.Error() != expectedErr {
       t.Fatalf("Failed, Unexpected error occured %v\n", err)
    }

   // Delete Fake DHCP file and cluster directories
   err = os.Remove("/var/lib/dhcp/dhcpd.leases")
   if err != nil {
      t.Logf("\nUnable to delete fake DHCP file\n")
   }
   err = os.RemoveAll("/multi-cluster/" + clusterName)
   if err != nil {
      t.Logf("\nUnable to delete cluster directory %s\n", clusterName)
   }
   err = os.RemoveAll("/multi-cluster/" + clusterName2)
   if err != nil {
      t.Logf("\nUnable to delete cluster directory %s\n", clusterName2)
   }
   err = os.RemoveAll("/multi-cluster/" + clusterName3)
   if err != nil {
      t.Logf("\nUnable to delete cluster directory %s\n", clusterName3)
   }


}

func simulateRequest(bpaCR *bpav1alpha1.Provisioning) reconcile.Request {
	namespacedName := types.NamespacedName{
		Name:      bpaCR.ObjectMeta.Name,
		Namespace: bpaCR.ObjectMeta.Namespace,
	}
	return reconcile.Request{NamespacedName: namespacedName}
}



func newBPA(name, namespace, clusterName, macAddress string) *bpav1alpha1.Provisioning {

     provisioningCR := &bpav1alpha1.Provisioning{
        ObjectMeta: metav1.ObjectMeta{
            Name:      name,
            Namespace: namespace,
            Labels: map[string]string{
                "cluster": clusterName,
            },
        },
        Spec: bpav1alpha1.ProvisioningSpec{
               Masters: []map[string]bpav1alpha1.Master{
                         map[string]bpav1alpha1.Master{
                           "test-master" : bpav1alpha1.Master{
                                 MACaddress: macAddress,
                            },

               },
              },
       },

    }
    return provisioningCR
}


func newBMList() *unstructured.UnstructuredList{

	bmMap := map[string]interface{}{
			   "apiVersion": "metal3.io/v1alpha1",
			   "kind": "BareMetalHostList",
			   "metaData": map[string]interface{}{
			       "continue": "",
				   "resourceVersion": "11830058",
				   "selfLink": "/apis/metal3.io/v1alpha1/baremetalhosts",

		 },
		 }




	metaData := map[string]interface{}{
			 "creationTimestamp": "2019-10-24T04:51:15Z",
			 "generation":"1",
			 "name": "fake-test-bmh",
			 "namespace": "default",
			 "resourceVersion": "11829263",
			 "selfLink": "/apis/metal3.io/v1alpha1/namespaces/default/baremetalhosts/bpa-test-bmh",
			 "uid": "e92cb312-f619-11e9-90bc-00219ba0c77a",
	}



	nicMap1 := map[string]interface{}{
			"ip": "",
			 "mac": "08:00:27:00:ab:2c",
			 "model": "0x8086 0x1572",
			 "name": "eth3",
			 "pxe": "false",
			 "speedGbps": "0",
			 "vlanId": "0",
	}

       nicMap2 := map[string]interface{}{
                        "ip": "",
                         "mac": "08:00:27:00:ab:1c",
                         "model": "0x8086 0x1572",
                         "name": "eth4",
                         "pxe": "false",
                         "speedGbps": "0",
                         "vlanId": "0",
        }

	specMap  := map[string]interface{}{
			  "status" : map[string]interface{}{
				   "errorMessage": "",
					"hardware": map[string]interface{}{
					   "nics": map[string]interface{}{
                                                "nic1" : nicMap1,
                                                "nic2" : nicMap2,
                                            },
			  },
			  },


	}

	itemMap := map[string]interface{}{
			   "apiVersion": "metal3.io/v1alpha1",
			   "kind": "BareMetalHost",
			   "metadata": metaData,
			   "spec": specMap,
		 }
	itemU := unstructured.Unstructured{
			 Object: itemMap,
		   }

	itemsList := []unstructured.Unstructured{itemU,}

	bmhList := &unstructured.UnstructuredList{
					Object: bmMap,
					Items: itemsList,
	 }


      return bmhList
}


// Create DHCP file for testing
func createFakeDHCP() error{


     dhcpData := []byte(`lease 192.168.50.63 {
  starts 4 2019/08/08 22:32:49;
  ends 4 2019/08/08 23:52:49;
  cltt 4 2019/08/08 22:32:49;
  binding state active;
  next binding state free;
  rewind binding state free;
  hardware ethernet 08:00:27:00:ab:2c;
  client-hostname "fake-test-bmh"";
}`)
     err := ioutil.WriteFile("/var/lib/dhcp/dhcpd.leases", dhcpData, 0777)

     if (err != nil) {
        return err
     }

    return nil
}
