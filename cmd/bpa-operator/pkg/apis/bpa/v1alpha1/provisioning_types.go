package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// EDIT THIS FILE!  THIS IS SCAFFOLDING FOR YOU TO OWN!
// NOTE: json tags are required.  Any new fields you add must have json tags for the fields to be serialized.

// ProvisioningSpec defines the desired state of Provisioning
// +k8s:openapi-gen=true
type ProvisioningSpec struct {
	// INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
	// Important: Run "operator-sdk generate k8s" to regenerate code after modifying this file
	// Add custom validation using kubebuilder tags: https://book-v1.book.kubebuilder.io/beyond_basics/generating_crd.html
	Masters []map[string]Master  `json:"masters,omitempty"`
	Workers []map[string]Worker  `json:"workers,omitempty"`
	KUDInstaller string `json:"kudInstallerPath,omitempty"`
	DHCPleaseFile string `json:"dhcpLeaseFile,omitempty"`
	MultiClusterPath string `json:"multiClusterDir,omitempty"`
}

// ProvisioningStatus defines the observed state of Provisioning
// +k8s:openapi-gen=true
type ProvisioningStatus struct {
	// INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
	// Important: Run "operator-sdk generate k8s" to regenerate code after modifying this file
	// Add custom validation using kubebuilder tags: https://book-v1.book.kubebuilder.io/beyond_basics/generating_crd.html
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Provisioning is the Schema for the provisionings API
// +k8s:openapi-gen=true
// +kubebuilder:subresource:status
type Provisioning struct {
	metav1.TypeMeta   `json:",inline"`
	metav1.ObjectMeta `json:"metadata,omitempty"`

	Spec   ProvisioningSpec   `json:"spec,omitempty"`
	Status ProvisioningStatus `json:"status,omitempty"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// ProvisioningList contains a list of Provisioning
type ProvisioningList struct {
	metav1.TypeMeta `json:",inline"`
	metav1.ListMeta `json:"metadata,omitempty"`
	Items           []Provisioning `json:"items"`
}

// master struct contains resource requirements for a master node
type Master struct {
	MACaddress string `json:"mac-address,omitempty"`
	CPU int32  `json:"cpu,omitempty"`
	Memory string  `json:"memory,omitempty"`
}

// worker struct contains resource requirements for a worker node
type Worker struct {
	MACaddress string `json:"mac-address,omitempty"`
	CPU int32 `json:"cpu,omitempty"`
	Memory string  `json:"memory,omitempty"`
	SRIOV bool  `json:"sriov,omitempty"`
	QAT  bool      `json:"qat,omitempty"`
}

func init() {
	SchemeBuilder.Register(&Provisioning{}, &ProvisioningList{})
}
