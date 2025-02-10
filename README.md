# Criação automatizada de cluster local do Kubernetes

## Pré-requisitos do kubeadm

Mínimo de dois nós Ubuntu [um nó master e um nó worker]. Você pode ter mais nós
worker conforme sua necessidade. O nó master deve ter no mínimo 2 vCPU e 2 GB
de RAM. Para os nós worker, é recomendado no mínimo 1 vCPU e 2 GB de RAM.
Intervalo de rede 10.X.X.X com IPs estáticos para nós master e worker. Usaremos a
série 172.x.x.x como o intervalo de rede do pod que será usado pelo plug-in de rede
Calico. Certifique-se de que o intervalo de IP do nó e o intervalo de IP do pod não se
sobreponham.


> **NOTA:**  
> Se você estiver configurando o cluster na rede corporativa por trás de um
proxy, certifique-se de definir as variáveis do proxy e ter acesso ao registro do
container e ao Docker Hub. Ou fale com seu administrador de rede para colocar o
registry.k8s.io na lista de permissões para conseguir baixar as imagens necessárias.
Requisitos de porta do kubeadm Se você estiver usando VMs Ubuntu baseadas em
Vagrant ou VirtualBox, o firewall é desabilitado por padrão. Então você não precisa
fazer nenhuma configuração de firewall.

## Requisitos de porta do kubeadm

Se você estiver usando VMs Ubuntu baseadas em
Vagrant ou VirtualBox, o firewall é desabilitado por padrão. Então você não precisa
fazer nenhuma configuração de firewall.

Caso contrário, consulte a imagem a seguir e certifique-se de que todas as portas sejam permitidas para o control plane (master) e os nós worker. Se você estiver configurando os servidores de nuvem do cluster kubeadm, certifique-se de permitir as portas na configuração do firewall.

![image](https://github.com/user-attachments/assets/4e52850a-f21b-4dac-a727-95a9181d6200)

## Configuração do cluster utilizando scripts

Após a criação e configuração das 3 VMs (uma para nó master e duas para nós worker) de acordo com os requisitos definidos anteriormente (3. Pré-requisitos do kubeadm e 4. Requisitos de porta do kubeadm), vamos instalar o kubeadm nos 3 nós seguinte os seguintes passos:

**PASSO 1:** Instalar cri-o, kubeadm, kubelet e kubectl em todos os nós  
**PASSO 2**: Inicializar kubeadm no Master p/ configurar Control Plane  
**PASSO 3**: Executar o comando para recriação do token  
**PASSO 4**: Adicionar nós Worker ao Master do cluster  
**PASSO 5**: Configurar o servidor de métricas do Kubernetes  
**PASSO 6**: Implantar uma aplicação Nginx como teste  
***
### PASSO 1: Instalar cri-o, kubeadm, kubelet e kubectl em todos os nós  
Execute o script *1st-run-all-nodes.sh* em cada um dos 3 nós do cluster para que o cri-o, kubeadm, kubelet e kubectl sejam instalados.

### PASSO 2: Inicializar kubeadm no Master p/ configurar Control Plane  
Execute o script *2nd-only-master.sh* somente no nó Master para configurar o Control Plane. Esse script instala, inclusive, o plugin de rede Calico.

### PASSO 3: Executar o comando para recriação do token  
Execute o seguinte comando no nó Master, como usuário root, para recriar o token que possibilita os nós Worker serem adicionados ao cluster:

```
kubeadm token create --print-join-command
```
A seguir é mostrado como o comando para adicionar o nó Worker se parece:
```
sudo kubeadm join 10.128.0.37:6443 --token j4eice.33vgvgyf5cxw4u8i \
     --discovery-token-ca-cert-hash sha256:37f94469b58bcc8f26a4aa44441fb17196a585b37288f85e22475b00c36f1c61
```
> **NOTA 1**  
> Use sudo se estiver executando como um usuário normal. Este comando executa o bootstrapping TLS para os nós.  

> **NOTA 2**  
> Substitua 10.128.0.37 pelo IP do nó Master.  

### PASSO 4: Adicionar nós Worker ao Master do cluster  
Em cada um dos nós Worker, execute o comando join mostrado acima para adicionar o nó Worker ao cluster.

Após a execução bem-sucedida, você verá a saída dizendo: “This node has joined the cluster”, conforme pode ser visto abaixo.  

![image](https://github.com/user-attachments/assets/9c352c37-8874-4b03-90fa-925210f09514)

Agora execute o seguinte comando kubectl no nó Master para verificar se os nós Worker foram adicionados ao cluster.
```
kubectl get nodes
```
Exemplo de saída:
```
root@controlplane:~# kubectl get nodes

NAME           STATUS   ROLES           AGE     VERSION
controlplane   Ready    control-plane   8m42s   v1.29.0
node01         Ready    <none>          2m6s    v1.29.0
```
Você pode **adicionar mais nós** com o mesmo comando join.

Você verificar os Pods no namespace kube-system, verá Pods Calico e Pods CoreDNS em execução. Faça isso usando o comando:
```
kubectl get po -n kube-system
```
Eis como a saída deve se parecer:

![image](https://github.com/user-attachments/assets/ef5b8976-37bb-4cb5-9d0d-514cc0d8f14c)

### PASSO 5: Configurar o servidor de métricas do Kubernetes  
O Kubeadm não instala o componente do servidor de métricas durante sua inicialização. Temos que instalá-lo separadamente.

Para instalar o servidor de métricas, execute o seguinte arquivo de manifesto do servidor de métricas, que faz o deploy do servidor de métricas:
```
kubectl apply -f https://raw.githubusercontent.com/techiescamp/kubeadm-scripts/main/manifests/metrics-server.yaml
```
Depois que os objetos do servidor de métricas são implantados, leva um minuto para você ver as métricas do nó e do pod usando o comando top.
```
kubectl top nodes
```
Você deverá conseguir visualizar as métricas do nó conforme mostrado abaixo.
```
root@controlplane:~# kubectl top nodes

NAME           CPU(cores)   CPU%   MEMORY(bytes)   MEMORY%
controlplane   142m         7%     1317Mi          34%
node01         36m          1%     915Mi           23%
```
### PASSO 6: Implantar uma aplicação Nginx como teste  
Agora que temos todos os componentes para fazer o cluster e os aplicativos funcionarem, vamos fazer o deploy uma aplicação Nginx de exemplo e ver se podemos acessá-la por meio de uma NodePort.

Crie um deployment Nginx. Execute o trecho de código a seguir diretamente na linha de comando. Ele faz o deploy do pod no namespace padrão.
```
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  selector:
    matchLabels:
      app: nginx
  replicas: 2 
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        ports:
        - containerPort: 80      
EOF
```
Exponha o deployment Nginx numa NodePort 32000, através de um service, da seguinte forma:
```
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
spec:
  selector: 
    app: nginx
  type: NodePort  
  ports:
    - port: 80
      targetPort: 80
      nodePort: 32000
EOF
```
Verifique o status do pod usando o seguinte comando:
```
kubectl get pods
```
Assim que a implantação estiver concluída, você deve conseguir acessar a página inicial do Nginx no NodePort alocado, conforme mostra a imagem a seguir.  

![image](https://github.com/user-attachments/assets/fb4c266c-71ac-482e-8c52-12f37f0ec1e6)

> **Observação:**  
> Veja mais detalhes sobre isso no artigo [Criação automatizada de cluster local do Kubernetes](https://medium.com/@ramonriserio/cria%C3%A7%C3%A3o-automatizada-de-cluster-local-do-kubernetes-e81c141ba368).  
