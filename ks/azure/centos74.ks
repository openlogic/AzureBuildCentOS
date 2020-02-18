# Kickstart for provisioning a CentOS 7.4 Azure VM

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
url --url=http://olcentgbl-masters.trafficmanager.net/centos/7.4.1708/os/x86_64/
repo --name="os" --baseurl="http://olcentgbl-masters.trafficmanager.net/centos/7.4.1708/os/x86_64/" --cost=100
repo --name="updates" --baseurl="http://olcentgbl-masters.trafficmanager.net/centos/7.4.1708/updates/x86_64/" --cost=100
repo --name="extras" --baseurl="http://olcentgbl-masters.trafficmanager.net/centos/7.4.1708/extras/x86_64/" --cost=100
repo --name="openlogic" --baseurl="http://olcentgbl.trafficmanager.net/openlogic/7/openlogic/x86_64/"

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
chrony
cifs-utils
sudo
python-pyasn1
parted
WALinuxAgent
hypervkvpd
gdisk
#cloud-init
cloud-utils-growpart
azure-repo-svc
-dracut-config-rescue

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Set these to the point release baseurls so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/OpenLogic.repo
sed -i -e 's/$releasever/7.4.1708/' -e 's/olcentbgl/olcentbgl-masters/' /etc/yum.repos.d/CentOS-Base.repo
sed -i -e 's/$releasever/7.4.1708/' -e 's/olcentbgl/olcentbgl-masters/' /etc/yum.repos.d/OpenLogic.repo

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Modify yum
echo "http_caching=packages" >> /etc/yum.conf

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
cat << EOF > /etc/modprobe.d/blacklist-floppy.conf
blacklist floppy
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
NM_CONTROLLED=no
PERSISTENT_DHCLIENT=yes
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
HOSTNAME=localhost.localdomain
EOF

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

# Disable NetworkManager handling of the SRIOV interfaces
curl -so /etc/udev/rules.d/68-azure-sriov-nm-unmanaged.rules https://raw.githubusercontent.com/LIS/lis-next/master/hv-rhel7.x/hv/tools/68-azure-sriov-nm-unmanaged

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable abrtd

# Download these again after the HPC build stage so we can recreate a previous point release without current major version updates
# Set OL repos
curl -so /etc/yum.repos.d/CentOS-Base.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/OpenLogic.repo

# Disable cloud-init config ... for now [RDA 200213]
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
	cat > /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<EOF
	# This configuration file is used to connect to the Azure DS sooner
	datasource_list: [ Azure ]
	EOF
fi


# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision
rm -f /etc/resolv.conf 2>/dev/null # workaround old agent bug

%end
