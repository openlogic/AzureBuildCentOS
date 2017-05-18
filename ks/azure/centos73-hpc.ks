# Kickstart for provisioning a RHEL 7.3 Azure HPC VM

# System authorization information
auth --enableshadow --passalgo=sha512

# Use graphical install
text

# Do not run the Setup Agent on first boot
firstboot --disable

# Keyboard layouts
keyboard --vckeymap=us --xlayouts='us'

# System language
lang en_US.UTF-8

# Network information
network --bootproto=dhcp

# Use network installation
url --url=http://olcentgbl.trafficmanager.net/centos/7.3.1611/os/x86_64/
repo --name="CentOS-Updates" --baseurl=http://olcentgbl.trafficmanager.net/centos/7.3.1611/updates/x86_64/

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,dnsmasq,NetworkManager"

# System timezone
timezone Etc/UTC --isUtc

# Partition clearing information
clearpart --all --initlabel

# Clear the MBR
zerombr

# Disk partitioning information
part /boot --fstype="xfs" --size=500
part / --fstype="xfs" --size=1 --grow --asprimary

# System bootloader configuration
bootloader --location=mbr --timeout=1

# Add OpenLogic repo
repo --name=openlogic --baseurl=http://olcentgbl.trafficmanager.net/openlogic/7/openlogic/x86_64/

# Firewall configuration
firewall --disabled

# Enable SELinux
selinux --enforcing

# Don't configure X
skipx

# Power down the machine after install
poweroff

# Disable kdump
%addon com_redhat_kdump --disable
%end

%packages
@base
@console-internet
ntp
cifs-utils
sudo
python-pyasn1
parted
WALinuxAgent
msft-rdma-drivers
selinux-policy-devel
rdma
librdmacm
libmlx4
dapl
libibverbs
kernel-headers
kernel-devel
-hypervkvpd
-dracut-config-rescue

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/OpenLogic.repo

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Set the kernel cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0"/g' /etc/default/grub

# Rebuild grub.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

# Enable SSH keepalive
sed -i 's/^#\(ClientAliveInterval\).*$/\1 180/g' /etc/ssh/sshd_config

# Configure network
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

# Disable persistent net rules
touch /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Disable some unneeded services by default
systemctl disable wpa_supplicant
systemctl disable abrtd

# Enable RDMA driver

  ## Install LIS4.1 with RDMA drivers
  ND="142"
  cd /opt/microsoft/rdma/rhel73
  rpm -i --nopre microsoft-hyper-v-rdma-*.${ND}-*.x86_64.rpm \
                 kmod-microsoft-hyper-v-rdma-*.${ND}-*.x86_64.rpm
  rm -f /initramfs-3.10.0-514.el7.x86_64.img
  rm -f /boot/initramfs-3.10.0-514.el7.x86_64.img
  echo -e "\nexclude=kernel*\n" >> /etc/yum.conf

  ## WALinuxAgent 2.2.x
  sed -i 's/^\#\s*OS.EnableRDMA=.*/OS.EnableRDMA=y/' /etc/waagent.conf
  systemctl enable hv_kvp_daemon.service

# Need to increase max locked memory
echo -e "\n# Increase max locked memory for RDMA workloads" >> /etc/security/limits.conf
echo '* soft memlock unlimited' >> /etc/security/limits.conf
echo '* hard memlock unlimited' >> /etc/security/limits.conf

# NetworkManager should ignore RDMA interface
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth1
DEVICE=eth1
ONBOOT=no
NM_CONTROLLED=no 
EOF

# Install Intel MPI
MPI="l_mpi-rt_2017.2.174"
CFG="IntelMPI-silent.cfg"
curl -so /tmp/${MPI}.tgz http://192.168.40.171/azure/${MPI}.tgz  ## Internal link to MPI package
curl -so /tmp/${CFG} https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/${CFG}
tar -C /tmp -zxf /tmp/${MPI}.tgz
/tmp/${MPI}/install.sh --silent /tmp/${CFG}
rm -rf /tmp/${MPI}* /tmp/${CFG}

# Fix SELinux for Hyper-V daemons
cat << EOF > /usr/share/selinux/devel/hyperv-daemons.te
module hyperv-daemons 1.0;
require {
type hypervkvp_t;
type device_t;
type hypervvssd_t;
class chr_file { read write open };
}
allow hypervkvp_t device_t:chr_file { read write open };
allow hypervvssd_t device_t:chr_file { read write open };
EOF
cd /usr/share/selinux/devel
make -f /usr/share/selinux/devel/Makefile hyperv-daemons.pp
semodule -s targeted -i hyperv-daemons.pp

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

%end
