#!/bin/bash
#
# Esse script deve ser executado em todos os nós, pois
# possui configurações comuns a todos os servidores (Control Plane e Workers)

# Execute esse script como root user

# O próximo comando garante que os pipelines falhem se qualquer comando dentro
# deles falhar e trata váriaveis não definidas como erros
set -euxo pipefail

# Declaração de variáveis do setup
KUBERNETES_VERSION="v1.30"
CRIO_VERSION="v1.30"
KUBERNETES_INSTALL_VERSION="1.30.0-1.1"

# O swap deve ser desabilitado para o correto funcionamento do Kubernetes
sudo swapoff -a

# O próximo comando faz com que swap permaneça desabilitado após o reboot
(crontab -l 2>/dev/null; echo "@reboot /sbin/swapoff -a") | crontab - || true
# TESTE IMPLEMENTAR SEM A PRÓXIMA LINHA DE COMANDO
# ------------------------------------------------
# sudo apt-get update -y

# Cria arquivo .conf para carregar os módulos a seguir na inicialização
# Módulos do kernel necessários para funcionamento da rede do Kubernetes
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

# Comandos a seguir carregam imediatamente módulos overlay e br_netfilter do kernel
sudo modprobe overlay
sudo modprobe br_netfilter

# Configura parâmetros do sysctl necessários para o funcionamento da rede
# do Kubernetes (que persistem após reinicializações)
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

# Aplicar parâmetros sysctl imediatamente (sem reinicializar)
sudo sysctl --system

# TESTE IMPLEMENTAR SEM AS PRÓXIMAS DUAS LINHAS DE COMANDO
# --------------------------------------------------------
sudo apt-get update -y
# sudo apt-get install -y apt-transport-https ca-certificates curl gpg

# Atualiza a lista de pacotes disponíveis e instala pacotes essenciais para 
# gerenciar propriedades de software, para manipular chaves GPG e para 
# garantir comunicação segurasudo apt-get update -y
# TESTE: A PRÓXIMA LINHA DE COMANDO FOI SUBSTITUÍDA PARA INCLUIR A INSTALAÇÃO DO GPG POR CAUSA DA RETIRADA DA LINHA 51 (teste)
# ----------------------------------------------------------------------------------------------------------------------------
# sudo apt-get install -y software-properties-common curl apt-transport-https ca-certificates
sudo apt-get install -y software-properties-common gpg curl apt-transport-https ca-certificates

# Baixa e adiciona a chave GPG para o repositório CRI-O para garantir a 
# autenticidade dos pacotes e adiciona o repositório CRI-O ao sistema para 
# que seja possível instalar pacotes CRI-O a partir dele
curl -fsSL https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/cri-o-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/cri-o-apt-keyring.gpg] https://pkgs.k8s.io/addons:/cri-o:/stable:/$CRIO_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/cri-o.list

# Atualiza novamente a lista de pacotes disponíveis e instala o container
# runtime do CRI-O
sudo apt-get update -y
sudo apt-get install -y cri-o

# Recarrega o daemon systemd, habilita o serviço CRI-O para iniciar na 
# inicialização e inicia o serviço CRI-O imediatamente.
sudo systemctl daemon-reload
sudo systemctl enable crio --now
sudo systemctl start crio.service

echo "CRI runtime installed successfully"

# crictl é uma CLI serve como uma ferramenta para gerenciar e depurar
# containers e imagens em um ambiente Kubernetes
# TESTE: Instale o crictl
wget https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.30.0/crictl-v1.30.0-linux-amd64.tar.gz
sudo tar zxvf crictl-v1.30.0-linux-amd64.tar.gz -C /usr/local/bin
rm -f crictl-v1.30.0-linux-amd64.tar.gz

# Os comandos a seguir baixa a chave GPG para o repositório APT do Kubernetes 
# e a adiciona ao conjunto de chaves do sistema.
curl -fsSL https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/Release.key |
    gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/$KUBERNETES_VERSION/deb/ /" |
    tee /etc/apt/sources.list.d/kubernetes.list

# Instale kubelet, kubectl, e kubeadm nas versões pré-definidas pelas variáveis no início deste script
sudo apt-get update -y
sudo apt-get install -y kubelet="$KUBERNETES_INSTALL_VERSION" kubectl="$KUBERNETES_INSTALL_VERSION" kubeadm="$KUBERNETES_INSTALL_VERSION"

# Previna atualizações automáticas do kubelet, kubeadm, e kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo apt-get update -y

# Instale o jq (processador de linha de comando JSON)
sudo apt-get install -y jq

# Obtenha o IP local do nó (no meu caso é o IP da interface enp0s8)
local_ip="$(ip --json addr show enp0s8 | jq -r '.[0].addr_info[] | select(.family == "inet") | .local')"

# Grave o IP local do nó no arquivo de configuração default do kubelet
cat > /etc/default/kubelet << EOF
KUBELET_EXTRA_ARGS=--node-ip=$local_ip
EOF
