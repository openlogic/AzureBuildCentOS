# Kickstart for provisioning a CentOS 6.10 Azure VM

# System authorization information
auth --enableshadow --passalgo=sha512

# Use graphical install
text

# Do not run the Setup Agent on first boot
firstboot --disable

# Keyboard layouts
keyboard us

# System language
lang en_US.UTF-8

# Network information
network --bootproto=dhcp

# Use network installation
url --url=http://olcentgbl.trafficmanager.net/centos/6.10/os/x86_64/
repo --name="CentOS-Updates" --baseurl=http://olcentgbl.trafficmanager.net/centos/6.10/updates/x86_64/
repo --name=openlogic --baseurl=http://olcentgbl.trafficmanager.net/openlogic/6/openlogic/x86_64/

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,ntpd,dnsmasq,hypervkvpd"

# System timezone
timezone Etc/UTC --isUtc

# Partition clearing information
clearpart --all --initlabel

# Clear the MBR
zerombr

# Disk partitioning information
part / --fstype="ext4" --size=1 --grow --asprimary

# System bootloader configuration
bootloader --location=mbr --append="console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 disable_mtrr_trim" --timeout=1

# Firewall configuration
firewall --disabled

# Enable SELinux
selinux --enforcing

# Don't configure X
skipx

# Power down the machine after install
poweroff

%packages
@base
@console-internet
@core
@debugging
@directory-client
@hardware-monitoring
@java-platform
@large-systems
@network-file-system-client
@performance
@perl-runtime
@server-platform
ntp
dnsmasq
cifs-utils
sudo
python-pyasn1
parted
WALinuxAgent
-dracut-config-rescue

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Remove unneeded parameters in grub
sed -i 's/ numa=off//g' /boot/grub/grub.conf
sed -i 's/ rhgb//g' /boot/grub/grub.conf
sed -i 's/ quiet//g' /boot/grub/grub.conf
sed -i 's/ crashkernel=auto//g' /boot/grub/grub.conf

# Set these to the point release baseurls so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/CentOS-Base.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/OpenLogic.repo
sed -i -e 's/$releasever/6.10/' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/$releasever/6.10/' /etc/yum.repos.d/OpenLogic.repo

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-6
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Enforce GRUB_TIMEOUT=1 and remove any existing GRUB_TIMEOUT_STYLE and append GRUB_TIMEOUT_STYLE=countdown after GRUB_TIMEOUT
sed -i -n -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' -e '/^GRUB_TIMEOUT_STYLE=/!p' -e '/^GRUB_TIMEOUT=/aGRUB_TIMEOUT_STYLE=countdown' /etc/default/grub

# Enable SSH keepalive
sed -i 's/^#\(ClientAliveInterval\).*$/\1 180/g' /etc/ssh/sshd_config

# Changing password retrictions defined by CIS CentOS Linux 6 Benchmark
sudo sed -i 's/pam_cracklib.so try_first_pass retry=3 type=/\pam_cracklib.so try_first_pass retry=3 minlen=14 dcredit=-1 ucredit=-1 ocredit=-1 lcredit=-1/g' /etc/pam.d/system-auth

# Configure network
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
PERSISTENT_DHCLIENT=yes
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

# Disable persistent net rules
touch /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules /etc/udev/rules.d/70-persistent-net.rules

# Disable some unneeded services by default (administrators can re-enable if desired)
chkconfig cups off

# Modify yum
echo "http_caching=packages" >> /etc/yum.conf
yum clean all

# Disable cloud-init config ... for now [RDA 200427]
if [ 0 = 1 ]
then
	# Disable provisioning and ephemeral disk handling in waagent.conf
	sed -i 's/Provisioning.Enabled=y/Provisioning.Enabled=n/g' /etc/waagent.conf
	sed -i 's/Provisioning.UseCloudInit=n/Provisioning.UseCloudInit=y/g' /etc/waagent.conf
	sed -i 's/ResourceDisk.Format=y/ResourceDisk.Format=n/g' /etc/waagent.conf
	sed -i 's/ResourceDisk.EnableSwap=y/ResourceDisk.EnableSwap=n/g' /etc/waagent.conf

	# Update the default cloud.cfg to move disk setup to the beginning of init phase
	sed -i '/ - mounts/d' /etc/cloud/cloud.cfg
	sed -i '/ - disk_setup/d' /etc/cloud/cloud.cfg
	sed -i '/cloud_init_modules/a\\ - mounts' /etc/cloud/cloud.cfg
	sed -i '/cloud_init_modules/a\\ - disk_setup' /etc/cloud/cloud.cfg
	cloud-init clean

	# Enable the Azure datasource
	cat > /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<-EOF
	# This configuration file is used to connect to the Azure DS sooner
	datasource_list: [ Azure ]
	EOF
fi

fi

# Download these again at the end of the post-install script so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/CentOS-Base.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/OpenLogic.repo

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

%end
