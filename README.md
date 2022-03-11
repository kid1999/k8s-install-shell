# k8s-install-shell

>  use a simple shell to build Kubernetes and dashboard in Centos7.



##  HOW TO USE

### Install K8S

> default install kubernetes1.19.4 + docker-ce-19.03.9 + calico

1. Prepare an environment with (Centos7, and make sure the network is available)

2.  Download the git files or git clone the repository

   ```shell
   git clone https://github.com/kid1999/k8s-install-shell.git
   ```

3. Enter directory and give shell files permissions.

   ```shell
   cd k8s-install-shell
   chmod 755 dashboard-install.sh k8s-install.sh
   ```

4. install Docker and Kubernetes.

   ```shell
   ./k8s-install.sh
   ```

   some options：

   1. set hostname default k8s-master
   2. this node is master-node? [y/n] default no
   3. set kube-api IP default 192.168.56.100
   4. choice the docker version to install
   5. choice the k8s version to install

5. init Kubernetes or join master node?

   * master node: init k8s，**install information and join shell save in ./kubeadm.log .**
   * work node: **join master node with shell in ./kubeadm.log .**

   

### Install Dashboard

> default install kubernetesui/dashboard:v2.5.1

1. Installed the K8S.

2. install dashboard.

   ```shell
   ./dashboard-install.sh
   ```

3. vist https://node-IP:30009 with token save in ./dashboard.log

   

