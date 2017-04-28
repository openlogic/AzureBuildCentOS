# Kickstart for provisioning a RHEL 7.1 Azure VM

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
url --url=http://vault.centos.org/7.1.1503/os/x86_64/
repo --name="CentOS-Updates" --baseurl=http://vault.centos.org/7.1.1503/updates/x86_64/

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,ntp,dnsmasq,NetworkManager"

# System timezone
timezone Etc/UTC --isUtc

# Partition clearing information
clearpart --all --initlabel

# Clear the MBR
zerombr

# Disk partitioning information
part / --fstype="ext4" --size=1 --grow --asprimary

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
hypervkvpd
-dracut-config-rescue

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/mooncake/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/mooncake/OpenLogic.repo

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Modify yum
echo "http_caching=packages" >> /etc/yum.conf

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

# Disable persistent net rules (FIXME: later we can just rely on net.ifnames)
touch /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules /etc/udev/rules.d/70-persistent-net.rules

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable wpa_supplicant
systemctl disable abrtd

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

%end
