# Kickstart for provisioning a CentOS 7.5 Azure HPC VM

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
url --url=http://olcentgbl-masters.trafficmanager.net/centos/7.5.1804/os/x86_64/
repo --name="CentOS-Updates" --baseurl=http://olcentgbl-masters.trafficmanager.net/centos/7.5.1804/updates/x86_64/

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,dnsmasq,NetworkManager"

# System timezone
timezone Etc/UTC --isUtc

# Partitioning and bootloader configuration
# Note: biosboot and efi partitions are pre-created %pre to work around blivet issue
zerombr
bootloader --location=mbr --timeout=1
# part biosboot --onpart=sda14 --size=4
part /boot/efi --onpart=sda15 --fstype=vfat --size=500
part /boot --fstype="xfs" --size=500
part / --fstype="xfs" --size=1 --grow --asprimary

%pre --log=/var/log/anaconda/pre-install.log --erroronfail
#!/bin/bash

# Pre-create the biosboot and EFI partitions
sgdisk --clear /dev/sda
sgdisk --new=14:2048:10239 /dev/sda
sgdisk --new=15:10240:500M /dev/sda
sgdisk --typecode=14:EF02 /dev/sda
sgdisk --typecode=15:EF00 /dev/sda

%end

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
selinux-policy-devel
rdma
librdmacm
libmlx4
dapl
libibverbs
kernel-headers
kernel-devel
libstdc++.i686
redhat-lsb
-hypervkvpd
-hyperv-daemons
-dracut-config-rescue
nfs-utils
# enable rootfs resize on boot
cloud-utils-growpart
gdisk

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Set these to the point release baseurls so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/OpenLogic.repo
sed -i -e 's/$releasever/7.5.1804/' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/$releasever/7.5.1804/' /etc/yum.repos.d/OpenLogic.repo

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Set the kernel cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0"/g' /etc/default/grub

# Enable grub serial console
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
sed -i 's/^GRUB_TERMINAL_OUTPUT=".*"$/GRUB_TERMINAL="serial console"/g' /etc/default/grub

# Enable BIOS bootloader
grub2-mkconfig --output /etc/grub2-efi.cfg
grub2-install --target=i386-pc --directory=/usr/lib/grub/i386-pc/ /dev/sda
grub2-mkconfig --output=/boot/grub2/grub.cfg

# Grab major version number so we can properly adjust grub config.
# Should work on both RHEL and CentOS reliably
majorVersion=$(rpm -E %{rhel})

 # Fix grub.cfg to remove EFI entries, otherwise "boot=" is not set correctly and blscfg fails
 [ "$majorVersion" = "7" ] && {
   EFI_ID=`blkid -s UUID -o value /dev/sda15`
   EFI_ID=`blkid -s UUID -o value /dev/sda1`
   sed -i 's|$prefix/grubenv|(hd0,gpt15)/efi/centos/grubenv|' /boot/grub2/grub.cfg
   sed -i 's|load_env|load_env -f (hd0,gpt15)/efi/centos/grubenv|' /boot/grub2/grub.cfg

   # Required for CentOS 7.x due to no blscfg: https://bugzilla.redhat.com/show_bug.cgi?id=1570991#c6
   #cat /etc/grub2-efi.cfg | sed -e 's|linuxefi|linux|' -e 's|initrdefi|initrd|' > /boot/grub2/grub.cfg
   sed -i -e 's|linuxefi|linux|' -e 's|initrdefi|initrd|' /boot/grub2/grub.cfg
 }
 [ "$majorVersion" = "8" ] && {
   EFI_ID=`blkid --match-tag UUID --output value /dev/sda15`
   BOOT_ID=`blkid --match-tag UUID --output value /dev/sda1`
   sed -i 's|${config_directory}/grubenv|(hd0,gpt15)/efi/centos/grubenv|' /boot/grub2/grub.cfg
 }
 sed -i 's/gpt15/gpt1/' /boot/grub2/grub.cfg
 sed -i "s/${EFI_ID}/${BOOT_ID}/" /boot/grub2/grub.cfg
 sed -i '/^### BEGIN \/etc\/grub.d\/30_uefi/,/^### END \/etc\/grub.d\/30_uefi/{/^### BEGIN \/etc\/grub.d\/30_uefi/!{/^### END \/etc\/grub.d\/30_uefi/!d}}' /boot/grub2/grub.cfg

# Blacklist the nouveau driver
cat << EOF > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

# Ensure Hyper-V drivers are built into initramfs
echo '# Ensure Hyper-V drivers are built into initramfs'	>> /etc/dracut.conf.d/azure.conf
echo -e "\nadd_drivers+=\"hv_vmbus hv_netvsc hv_storvsc\""	>> /etc/dracut.conf.d/azure.conf
kversion=$( rpm -q kernel | sed 's/kernel\-//' )
dracut -v -f "/boot/initramfs-${kversion}.img" "$kversion"

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
PERSISTENT_DHCLIENT=yes
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

# Disable persistent net rules
ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /etc/udev/rules.d/70-persistent-net.rules

# Disable NetworkManager handling of the SRIOV interfaces
cat <<EOF > /etc/udev/rules.d/68-azure-sriov-nm-unmanaged.rules

# Accelerated Networking on Azure exposes a new SRIOV interface to the VM.
# This interface is transparently bonded to the synthetic interface,
# so NetworkManager should just ignore any SRIOV interfaces.
SUBSYSTEM=="net", DRIVERS=="hv_pci", ACTION=="add", ENV{NM_UNMANAGED}="1"

EOF

# Disable some unneeded services by default
systemctl disable wpa_supplicant
systemctl disable abrtd

# Enable RDMA driver

  ## Install LIS4.1 with RDMA drivers
  ND="144"
  cd /opt/microsoft/rdma/rhel75
  rpm -i --nopre microsoft-hyper-v-rdma-*.${ND}-*.x86_64.rpm \
                 kmod-microsoft-hyper-v-rdma-*.${ND}-*.x86_64.rpm
  rm -f /initramfs-3.10.0-693.el7.x86_64.img 2> /dev/null
  rm -f /boot/initramfs-3.10.0-693.el7.x86_64.img 2> /dev/null
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
MPI="l_mpi-rt_p_5.1.3.223"
CFG="IntelMPI-v5.x-silent.cfg"
##curl -so /tmp/${MPI}.tgz http://192.168.40.171/azure/${MPI}.tgz  ## Internal link to MPI package
curl -so /tmp/${MPI}.tgz http://olcentwus.cloudapp.net/openlogic/${MPI}.tgz  ## Link to MPI package
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

# Modify yum, sync history, clean cache
echo "http_caching=packages" >> /etc/yum.conf
yum history sync
yum clean all

# Download these again after the HPC build stage so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/OpenLogic.repo

# Set tuned profile
echo "virtual-guest" > /etc/tuned/active_profile

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

%end
