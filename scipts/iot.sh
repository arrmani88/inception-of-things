#!/bin/bash

# before running:
#   add 1 CPU to the machine (system -> processor)

sudo apt-get update
sudo apt install curl -y
sudo apt install openssh-server
sudo apt install vim -y

#install docker
echo "----------- INSTALLING DOCKER... -----------"
sudo apt install apt-transport-https ca-certificates curl software-properties-common -y
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu focal stable"
sudo apt install docker-ce -y
sudo usermod -aG docker ${USER}

# install kubelet kubeadm kubectl
echo "----------- INSTALLING kubelet kubeadm kubectl... -----------"
sudo curl -fsSLo /etc/apt/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

#install k3d
echo "----------- INSTALLING K3D... -----------"
wget -q -O - https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash

#disable swap # no need to disable it since we added 1 CPU
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#filling KUBECONFING to avoid this error: Kubectl the connection to the server localhost:8080 was refused
echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> ~/.bashrc
source ~/.bashrc

# to avoid this: container runtime is not running. unknown service runtime.v1.RuntimeService -> https://k21academy.com/docker-kubernetes/container-runtime-is-not-running/
sudo rm /etc/containerd/config.toml
sudo systemctl restart containerd

# echo "#init kubeadm to generate /etc/kubernetes/admin.conf"
sudo kubeadm init

# dont need this if set the variable KUBECONFIG
# mkdir -p $HOME/.kube
# sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
# sudo chown $(id -u):$(id -g) $HOME/.kube/config

# echo "#create cluster"
sudo k3d cluster create iot-cluster --api-port 6445 -p 80:80@loadbalancer

# echo "#create namespaces"
sudo kubectl create namespace argocd
sudo kubectl create namespace dev

# echo "#argocd "
sudo kubectl apply -f ../config/install.yaml -n argocd

# expose the argocd-server service as a LoadBalancer type to access the ArgoCD UI from outside of the cluster.
# sudo kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# echo "#apply the ingress config in argocd namespace"
sudo kubectl apply -f ../config/ingress.yaml -n argocd

# Wait for the Argo CD pod to be in a Running state
while [[ $(kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do
  sleep 1
done

# Argo UI by default will run on port 80. To access it on port 8090 or any other alternative port on the local machine,
sudo kubectl port-forward -n argocd svc/argocd-server 8080:443

# patch the argocd-secret secret in the argocd namespace. Specifically, it is updating
# the contents of the argocd-secret secret by setting two key-value pairs in the stringData field
kubectl -n argocd patch secret argocd-secret \
  -p '{"stringData":  {
    "admin.password": "$2a$12$Q7carOnqUto8BEcGpeu1EuWMZT9jrNBdLr2nXxPsbP2Ds65eVFIZ6",
    "admin.passwordMtime": "'$(date +%FT%T%Z)'"
  }}'
# string 'password' crypted = $2a$12$Q7carOnqUto8BEcGpeu1EuWMZT9jrNBdLr2nXxPsbP2Ds65eVFIZ6

# apply the app config
sudo kubectl apply -f ../config/application.yaml

# apply the project config to all applications that inside this projec
sudo kubectl apply -f ../config/project.yaml -n argocd
