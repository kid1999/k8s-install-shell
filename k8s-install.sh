#! /bin/bash
# author: kid.1447250889@live.com
# date: 2022-03-10
# des: Automatic deployment Kubernetes in CentOS7
# environment: Centos-7.6 + kubernetes1.19.4 + docker-ce-19.03.9 + calico

# choice the k8s version and docker version by themselves, but offer the default configuration.



# ------------------------------------log--------------------------------------------------------------
# success log
log_success() {
  echo -e "\e[32m $1\e[0m"
}
# info log
log_info() {
  echo -e "\e[33m $1\e[0m"
}
# error log
log_error() {
  echo -e "\e[31m $1\e[0m"
  exit
}

log_success "Thank you use k8s auto install shell!"


# ------------------------------------set hostname----------------------------------------------------
read -p "set hostname default k8s-master: " HOST_NAME
if test ! -n "$HOST_NAME"; then
  HOST_NAME="k8s-master"
fi
hostnamectl set-hostname $HOST_NAME
log_info "hostname is $HOST_NAME "

read -p "this node is master-node? [y/n] default no: " IS_MASTER
if test "$IS_MASTER" = "y"; then
  read -p "set kube-api IP default 192.168.56.100: " KUBE_API_IP
  if test -z "$KUBE_API_IP"; then
    KUBE_API_IP="192.168.56.100"
  fi
fi
log_info "kube-api IP is $KUBE_API_IP"
if test $?; then
  log_success "setting hostname ok ..."
fi


# ------------------------------------disable firewalld-----------------------------------------------
log_info "disable firewalld ..."
systemctl stop firewalld && systemctl disable firewalld
if test $?; then
  log_success "firewall disable ok..."
else
  log_error "firewall disable fail "
fi


# ------------------------------------off swap -------------------------------------------------------
log_info "off swap ..."
swapoff -a && sed -ri 's/.*swap.*/#&/' /etc/fstab
if test $?; then
  log_success "swap off ok ..."
else
  log_error "swap off fail"
fi


# ------------------------------------load modules ---------------------------------------------------
log_info "Load the required kernel modules"
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
modprobe overlay
if test $?; then
  log_success "modprobe overlay ok ..."
else
  log_error "modprobe overlay fail"
fi
modprobe br_netfilter
if test $?; then
  log_success "modprobe br_netfilter ok ..."
else
  log_error "modprobe br_netfilter fail"
fi


# ------------------------------------load ipvs modules ----------------------------------------------
log_info "add ipvs modules ..."
cat >/etc/modules-load.d/ipvs.conf <<EOF
# Load IPVS at boot
ip_vs
ip_vs_rr
ip_vs_wrr
ip_vs_sh
nf_conntrack_ipv4
EOF
log_info "enable now systemd modules service ..."
systemctl enable --now systemd-modules-load.service
if test $?; then
  lsmod | grep -e ip_vs -e nf_conntrack_ipv4
  log_success "ipvs load ok..."
else
  log_error "ipvs load fail"
fi

# ------------------------------------install epel-release  -----------------------------------------
log_info "install epel-release ... "
yum install -y epel-release

# ------------------------------------install ipset ipvsadm -----------------------------------------
log_info "install ipset ipvsadm ... "
yum install -y ipset ipvsadm
if test $?; then
  log_success "ipset ipvsadm install ok..."
else
  log_error "ipset ipvsadm install fail"
fi


# ------------------------------------set sysctl allow iptables -------------------------------------
log_info "set sysctl allow iptables forward, kubernetes-cri conf  ... "
log_info "set iptalbes bridge call and forward..."
cat <<EOF | sudo tee /etc/sysctl.d/kubernetes-cri.conf
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
vm.swappiness                       = 0
net.bridge.bridge-nf-call-ip6tables = 1
EOF
echo -e "\n\n"
sysctl --system
if test $?; then
  log_success "set sysctl allow iptables forward, kubernetes-cri conf ok"
else
  log_error "set sysctl allow iptables forward, kubernetes-cri conf fial"
fi


# ------------------------------------install yum tool ----------------------------------------------
log_info "install yum-utils device-mapper-persistent-data lvm2... "
yum install -y yum-utils device-mapper-persistent-data lvm2 vim net-tools bash-completion
if test $?; then
  log_success "install yum-utils device-mapper-persistent-data lvm2 ok "
else
  log_error "install yum-utils device-mapper-persistent-data lvm2 fail "
fi


# ------------------------------------install docker ce ---------------------------------------------
log_info "--add-repo     https://download.docker.com/linux/centos/docker-ce.repo ..."
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
if test $?; then
  log_success "--add-repo ok"
else
  log_success "--add-repo fail"
fi

read -p "choice the docker version you want to install, default install docker-ce-19.03.9: " DOCKER_VERSION
if test ! -n "$DOCKER_VERSION"; then
  DOCKER_VERSION="19.03.9"
fi
log_info "install docker-ce-$DOCKER_VERSION and docker-cli-$DOCKER_VERSION ."
yum install -y docker-ce-$DOCKER_VERSION docker-cli-$DOCKER_VERSION
if test $?; then
  log_success "install docker-ce-19.03.9 docker-cli-19.03.9 ok"
else
  log_fail "install docker-ce-19.03.9 docker-cli-19.03.9 fail"
fi

systemctl enable docker
if test $?; then
  log_success "enable docker ok "
else
  log_fail "enable docker fail"
fi
systemctl start docker
if test $?; then
  log_success "start docker ok "
else
  log_fail "start docker fail"
fi

# ------------------------------------registry mirrors- ---------------------------------------------
log_info "set docker registry mirrors..."
cat <<EOF | sudo tee /etc/docker/daemon.json
{ 
 "registry-mirrors": ["https://9qdic84f.mirror.aliyuncs.com"],
 "exec-opts": ["native.cgroupdriver=systemd"]
}
EOF

sudo systemctl restart docker
if test $?; then
  log_success "reload docker ok "
else
  log_fail "reload docker fail"
fi


# ------------------------------------docker network iptables forward service -----------------------
log_info "set docker network iptables forward service..."
CONFIG_PATH=/lib/systemd/system/docker.service
sed -i '/ExecStartPost=/d' $CONFIG_PATH
sed -i '/ExecStart=/i ExecStartPost=/sbin/iptables -I FORWARD -s 0.0.0.0/0 -j ACCEPT' $CONFIG_PATH
if test $?; then
  log_success "set docker network iptables forward service ok "
else
  log_fail "set docker network iptables forward service fail"
fi

# ------------------------------------set kubernetes yum mirrors ------------------------------------
log_info "set kubernetes yum mirrors..."
cat <<EOF >/etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF

# ------------------------------------install kubernetes --------------------------------------------
read -p "choice the k8s version you want to install, default install kubelet-1.20.4: " K8S_VERSION
if test ! -n "$K8S_VERSION"; then
  K8S_VERSION="1.20.4"
fi

log_info "install kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION..."
yum install -y kubelet-$K8S_VERSION kubeadm-$K8S_VERSION kubectl-$K8S_VERSION

if test $?; then
  log_success "install kubelet-1.20.4 kubeadm-1.20.4 kubectl-1.20.4 ok "
else
  log_fail "install kubelet-1.20.4 kubeadm-1.20.4 kubectl-1.20.4 fail"
fi
systemctl enable kubelet
if test $?; then
  log_success "enable kubelet ok "
else
  log_fail "enable kubelet fail"
fi
systemctl enable kubelet
if test $?; then
  log_success "start kubelet ok "
else
  log_fail "start kubelet fail"
fi


# ------------------------------------time synchronization ------------------------------------------
log_info "yum install ntpdate..."
yum install -y ntpdate
if test $?; then
  log_success "install ntpdate ok "
else
  log_fail "install ntpdate fail"
fi

log_info "time synchronization..."
ntpdate time.windows.com
if test $?; then
  log_success "time synchronization ok "
else
  log_fail "time synchronization fail"
fi


# ------------------------------------kubectl completion bash ---------------------------------------
echo "source <(kubectl completion bash)" >>~/.bashrc
source ~/.bashrc
if test $?; then
  log_success "kubectl completion bash ok "
else
  log_fail "kubectl completion bash fail"
fi


# ------------------------------------kubeadm init config--------------------------------------------

if test "$IS_MASTER" = "y"; then
  log_info "create kubeadm-config.yaml..."
  cat >kubeadm-config.yaml <<EOF
apiVersion: kubelet.config.k8s.io/v1beta1
kind: KubeletConfiguration
failSwapOn: false
#禁用swap检测
cgroupDriver: systemd
#修改driver为systemd
#rotateCertificates: true
# 开启证书轮询
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: InitConfiguration
localAPIEndpoint:
  advertiseAddress: ${KUBE_API_IP}
  bindPort: 6443
nodeRegistration:
  taints:
  - effect: PreferNoSchedule
    key: node-role.kubernetes.io/master
---
apiVersion: kubeadm.k8s.io/v1beta2
kind: ClusterConfiguration
imageRepository: registry.aliyuncs.com/google_containers
kubernetesVersion: v1.20.4
networking:
  podSubnet: 10.244.0.0/16
  serviceSubnet: 10.96.0.0/12
# apiServer:
#   extraArgs:
#     service-node-port-range: "1-65535"
---
apiVersion: kubeproxy.config.k8s.io/v1alpha1
kind: KubeProxyConfiguration
clusterCIDR: "10.244.0.0/16"
mode: "ipvs"
EOF

  log_info "kubeadm init..."
  kubeadm init --config kubeadm-config.yaml >&1 | tee ./kubeadm.log

  if test $?; then
    log_success "kubeadm init ok "
  else
    log_fail "kubeadm init fail"
  fi
  echo export KUBECONFIG=/etc/kubernetes/admin.conf >> ~/.bash_profile
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  # ------------------------------------kube-proxy-calico --------------------------------------------------
  log_info "apply kube-proxy..."
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
  if test $?; then
    log_success "kube-proxy install ok "
  else
    log_fail "kube-proxy install fail"
  fi
  exit
fi

exit