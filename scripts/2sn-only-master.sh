
#!/bin/bash
#
# Após executar o script "1st-run-all-nodes.sh" (a ser executado em todos os nós, inclusive o master),
# execute esse script somente no nó Master para congirar o Control Plane

# Execute esse script como root user

# O próximo comando garante que os pipelines falhem se qualquer comando dentro deles falhar
# e trata váriaveis não definidas como erros
set -euxo pipefail

# Se você precisa de acesso público ao API server usando IP público dos servidores, mude PUBLIC_IP_ACCESS para "true".
PUBLIC_IP_ACCESS="false"
NODENAME=$(hostname -s)
POD_CIDR="172.168.0.0/16"

# Faz o download das imagens requeridas
sudo kubeadm config images pull

# Inicialize o kubeadm baseado no PUBLIC_IP_ACCESS

if [[ "$PUBLIC_IP_ACCESS" == "false" ]]; then
    
    MASTER_PRIVATE_IP=$(ip addr show enp0s8 | awk '/inet / {print $2}' | cut -d/ -f1)
    sudo kubeadm init --apiserver-advertise-address="$MASTER_PRIVATE_IP" --apiserver-cert-extra-sans="$MASTER_PRIVATE_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap

elif [[ "$PUBLIC_IP_ACCESS" == "true" ]]; then

    MASTER_PUBLIC_IP=$(curl ifconfig.me && echo "")
    sudo kubeadm init --control-plane-endpoint="$MASTER_PUBLIC_IP" --apiserver-cert-extra-sans="$MASTER_PUBLIC_IP" --pod-network-cidr="$POD_CIDR" --node-name "$NODENAME" --ignore-preflight-errors Swap

else
    echo "Error: MASTER_PUBLIC_IP has an invalid value: $PUBLIC_IP_ACCESS"
    exit 1
fi

# Crie e configure o kubeconfig
mkdir -p "$HOME"/.kube
sudo cp -i /etc/kubernetes/admin.conf "$HOME"/.kube/config
sudo chown "$(id -u)":"$(id -g)" "$HOME"/.kube/config

# Instale o plugin de rede Calico Network
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
