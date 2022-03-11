#! /bin/bash
# author: kid.1447250889@live.com
# date: 2022-03-10
# des: Automatic deployment Kubernetes in CentOS7
# environment: Centos-7.6 + kubernetes1.19.4 + docker-ce-19.03.9 + calico

# install the dashboard after installed the kubernetes.

# success log
log_success() {
  echo -e "\e[32m $1\e[0m"
}

# # # ------------------------------------install dashboard--------------------------------------------------------------
# # more infomation, pleace read the yaml file recommended.yaml
kubectl create -f recommended.yaml

# # # ------------------------------------create access user--------------------------------------------------------------
kubectl create serviceaccount dashboard-admin -n kubernetes-dashboard
kubectl create clusterrolebinding dashboard-admin-rb --clusterrole=cluster-admin --serviceaccount=kubernetes-dashboard:dashboard-admin
SECRETS=$(kubectl get secrets -n kubernetes-dashboard | grep dashboard-admin)
TOKEN=${SECRETS%%kubernetes*}
kubectl describe secrets $TOKEN -n kubernetes-dashboard >&1 | tee ./dashboard.log
if test $?; then
  log_success "dashboard installed success, token storage in ./dashboard.log . pleace vist https://node-IP:30009"
else
  log_error "installed fail "
fi

