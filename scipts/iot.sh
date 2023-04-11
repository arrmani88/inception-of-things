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
# sudo swapoff -a
# sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

#filling KUBECONFING to avoid this error: Kubectl the connection to the server localhost:8080 was refused
echo "export KUBECONFIG=\"/etc/kubernetes/admin.conf\"" >> ~/.bashrc
source ~/.bashrc

# to avoid this: container runtime is not running. unknown service runtime.v1.RuntimeService -> https://k21academy.com/docker-kubernetes/container-runtime-is-not-running/
sudo rm /etc/containerd/config.toml
sudo systemctl restart containerd

#init kubeadm to generate /etc/kubernetes/admin.conf
sudo kubeadm init

#create cluster
sudo k3d cluster create --config ../config/iot-cluster.yaml

#create and configure namespace
sudo kubectl create namespace argocd
sudo kubectl apply -f ../config/install-argocd.yaml -n argocd

#apply the ingress config in argocd namespace
sudo kubectl apply -f ../config/ingress.yaml -n argocd

#create namespaces
sudo kubectl apply -f ../config/argocd-namespace.yaml
sudo kubectl apply -f ../config/dev-namespace.yaml

