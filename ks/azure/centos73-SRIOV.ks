# Kickstart for provisioning a RHEL 7.3 Azure VM w/SRIOV networking support

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
chrony
cifs-utils
sudo
python-pyasn1
parted
WALinuxAgent
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
BOOTPROTO=none
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=yes
MASTER=bond0
SLAVE=yes
NM_CONTROLLED=no
EOF

cat << EOF > /etc/sysconfig/network-scripts/ifcfg-vf1
DEVICE=vf1
ONBOOT=yes
TYPE=Ethernet
BOOTPROTO=none
PEERDNS=yes
IPV6INIT=yes
MASTER=bond0
SLAVE=yes
NM_CONTROLLED=no
EOF

# Configure bonding for SR-IOV (bond synthetic and vf NICs)
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-bond0
DEVICE=bond0
TYPE=Bond
BOOTPROTO=dhcp
ONBOOT=yes
PEERDNS=yes
IPV6INIT=yes
BONDING_MASTER=yes
BONDING_OPTS="mode=active-backup miimon=100 primary=vf1"
NM_CONTROLLED=no
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

# Assign Hyper-V VF NICs to stable names
curl -o /etc/udev/rules.d/60-hyperv-vf-name.rules https://raw.githubusercontent.com/LIS/lis-next/master/tools/sriov/60-hyperv-vf-name.rules

# On HyperV/Azure VMs, we use VF serial number as the PCI domain. This number
# is used as part of VF nic names for persistency.
curl -o /usr/sbin/hv_vf_name https://raw.githubusercontent.com/LIS/lis-next/master/tools/sriov/hv_vf_name
chmod 755 /usr/sbin/hv_vf_name

# Deploy new configuration
cat <<EOF > /etc/pam.d/system-auth-ac

auth        required      pam_env.so
auth        sufficient    pam_fprintd.so
auth        sufficient    pam_unix.so nullok try_first_pass
auth        requisite     pam_succeed_if.so uid >= 1000 quiet_success
auth        required      pam_deny.so

account     required      pam_unix.so
account     sufficient    pam_localuser.so
account     sufficient    pam_succeed_if.so uid < 1000 quiet
account     required      pam_permit.so

password    requisite     pam_pwquality.so try_first_pass local_users_only retry=3 authtok_type= ucredit=-1 lcredit=-1 dcredit=-1 ocredit=-1
password    sufficient    pam_unix.so sha512 shadow nullok try_first_pass use_authtok remember=5
password    required      pam_deny.so

session     optional      pam_keyinit.so revoke
session     required      pam_limits.so
-session     optional      pam_systemd.so
session     [success=1 default=ignore] pam_succeed_if.so service in crond quiet use_uid
session     required      pam_unix.so

EOF

# Disable persistent net rules
touch /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable abrtd

# Install LIS 4.2 (includes hv_pci support)
LISHV="microsoft-hyper-v-4.2.1-20170602.x86_64.rpm"
LISKMOD="kmod-microsoft-hyper-v-4.2.1-20170602.x86_64.rpm"
curl -so /tmp/${LISHV} http://olcentgbl.trafficmanager.net/openlogic/7.3.1611/openlogic/x86_64/RPMS/${LISHV}
curl -so /tmp/${LISKMOD} http://olcentgbl.trafficmanager.net/openlogic/7.3.1611/openlogic/x86_64/RPMS/${LISKMOD}
rpm -i --nopre /tmp/${LISHV} \
               /tmp/${LISKMOD}
rm -f /tmp/${LISHV} \
      /tmp/${LISKMOD}
rm -f /initramfs-3.10.0-514.el7.x86_64.img 2>/dev/null
rm -f /boot/initramfs-3.10.0-514.el7.x86_64.img 2>/dev/null

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision
rm -f /etc/resolv.conf 2>/dev/null # workaround old agent bug

%end
