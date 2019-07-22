1. Installed Ubuntu 16.04, Kubeadm, Kubelet, and Kubectl on baremetal
2. Cloned repo "https://github.com/kubernetes-sigs/node-feature-discovery.git"- git clone https://github.com/kubernetes-sigs/node-feature-discovery.git
3. Create nfd ns - kubectl create namespace node-feature-discovery
4. Use nfd ns - kubectl config set-context --current --namespace=node-feature-discovery
5. Apply nfd for single baremetal server - kubectl apply -f nfd-daemonset-combined.yaml.template
