#!/bin/bash
# 0. Thay doi hostname va cap nhat file hosts
hostnamectl set-hostname worker1.com
cat >>/etc/hosts<<EOF
  192.168.56.100 master.com
  192.168.56.102 worker1.com
  192.168.56.104 worker2.com
EOF
 
# 1. Tat firewall
systemctl disable firewalld
# 2. Tat Selinux
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
# 3. Tat swap
sed -i '/swap/d' /etc/fstab
swapoff -a
# 4. Cai dat docker
yum -y update
yum -y install yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum -y install docker-ce
# 5. Setup daemon.
cat > /etc/docker/daemon.json <<EOF
{
  "exec-opts": ["native.cgroupdriver=systemd"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m"
  },
  "storage-driver": "overlay2",
  "storage-opts": [
    "overlay2.override_kernel_check=true"
  ]
}
EOF
# 6.Restart Docker
systemctl start docker
systemctl enable docker
systemctl daemon-reload


# 7. Cap nhat kernal sysctl
cat >>/etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF
sysctl --system

# 8. Add yum repo file for Kubernetes

cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
enabled=1
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF

# 9. Cai dat kubernetes
yum install -y kubeadm
systemctl start kubelet
systemctl enable kubelet

# 10. Cai dat containerd
yum -y install containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
systemctl start containerd

# 11. Restart All
systemctl restart docker
systemctl restart kubelet
systemctl restart containerd
reboot