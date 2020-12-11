# Kickstart for provisioning a CentOS 8.2 Azure VM

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
url --url="http://olcentgbl.trafficmanager.net/centos/8.2.2004/BaseOS/x86_64/os/"
repo --name "BaseOS" --baseurl="http://olcentgbl.trafficmanager.net/centos/8.2.2004/BaseOS/x86_64/os/" --cost=100
repo --name="AppStream" --baseurl="http://olcentgbl.trafficmanager.net/centos/8.2.2004/AppStream/x86_64/os/" --cost=100
repo --name="OpenLogic" --baseurl="http://olcentgbl.trafficmanager.net/openlogic/8/openlogic/x86_64/"

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,NetworkManager,systemd-resolved"

# System timezone
timezone Etc/UTC --isUtc

# Firewall configuration
firewall --disabled

# Enable SELinux
selinux --enforcing

# Don't configure X
skipx

# Power down the machine after install
poweroff

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


# Disable kdump
%addon com_redhat_kdump --disable
%end

%packages
WALinuxAgent
@^minimal-environment
@standard
#@container-tools
chrony
sudo
parted
cloud-init
cloud-utils-growpart
-dracut-config-rescue
-postfix
-NetworkManager-config-server
grub2-pc
grub2-pc-modules 
openssh-server
kernel
dnf-utils
rng-tools
cracklib
cracklib-dicts
centos-release
bind-utils
python3
timedatex

# pull firmware packages out
-aic94xx-firmware
-alsa-firmware
-alsa-lib
-alsa-tools-firmware
-ivtv-firmware
-iwl1000-firmware
-iwl100-firmware
-iwl105-firmware
-iwl135-firmware
-iwl2000-firmware
-iwl2030-firmware
-iwl3160-firmware
-iwl3945-firmware
-iwl4965-firmware
-iwl5000-firmware
-iwl5150-firmware
-iwl6000-firmware
-iwl6000g2a-firmware
-iwl6000g2b-firmware
-iwl6050-firmware
-iwl7260-firmware
-libertas-sd8686-firmware
-libertas-sd8787-firmware
-libertas-usb8388-firmware

# Some things from @core we can do without in a minimal install
-biosdevname
-plymouth
-iprutils

gdisk

%end


%post --log=/var/log/anaconda/post-install.log --erroronfail

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Import CentOS public key
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-centosofficial

# Set OL repo and import OpenLogic public key
curl -so /etc/yum.repos.d/OpenLogicCentOS.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/CentOS-Base-8.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/OpenLogic.repo
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Set options for proper repo fallback
dnf config-manager --setopt=skip_if_unavailable=1 --setopt=timeout=10 --setopt=fastestmirror=0 --save
dnf config-manager --setopt=\*.skip_if_unavailable=1 --setopt=\*.timeout=10 --setopt=\*.fastestmirror=0 --save \*
sed -i -e 's/^mirrorlist/#mirrorlist/' -e 's/^#baseurl/baseurl/' /etc/yum.repos.d/CentOS*.repo

# Set these to the point release baseurls so we can recreate a previous point release without current major version updates
sed -i -e 's/$releasever/8.2.2004/g' /etc/yum.repos.d/OpenLogicCentOS.repo
yum-config-manager --disable AppStream BaseOS extras

# Set the kernel cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 scsi_mod.use_blk_mq=y"/g' /etc/default/grub

# Enforce GRUB_TIMEOUT=1 and remove any existing GRUB_TIMEOUT_STYLE and append GRUB_TIMEOUT_STYLE=countdown after GRUB_TIMEOUT
sed -i -n -e 's/GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' -e '/^GRUB_TIMEOUT_STYLE=/!p' -e '/^GRUB_TIMEOUT=/aGRUB_TIMEOUT_STYLE=countdown' /etc/default/grub

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
}
sed -i 's/gpt15/gpt1/' /boot/grub2/grub.cfg
sed -i "s/${EFI_ID}/${BOOT_ID}/" /boot/grub2/grub.cfg
sed -i 's|${config_directory}/grubenv|(hd0,gpt15)/efi/centos/grubenv|' /boot/grub2/grub.cfg
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

# Enable SSH keepalive / Disable root SSH login
sed -i 's/^#\(ClientAliveInterval\).*$/\1 180/g' /etc/ssh/sshd_config
sed -i 's/^PermitRootLogin.*/#PermitRootLogin no/g' /etc/ssh/sshd_config

# Configure network
cat << EOF > /etc/sysconfig/network-scripts/ifcfg-eth0
DEVICE=eth0
ONBOOT=yes
BOOTPROTO=dhcp
TYPE=Ethernet
USERCTL=no
PEERDNS=yes
IPV6INIT=no
NM_CONTROLLED=yes
PERSISTENT_DHCLIENT=yes
EOF

cat << EOF > /etc/sysconfig/network
NETWORKING=yes
EOF

# Disable NetworkManager handling of the SRIOV interfaces
cat <<EOF > /etc/udev/rules.d/68-azure-sriov-nm-unmanaged.rules

# Accelerated Networking on Azure exposes a new SRIOV interface to the VM.
# This interface is transparently bonded to the synthetic interface,
# so NetworkManager should just ignore any SRIOV interfaces.
SUBSYSTEM=="net", DRIVERS=="hv_pci", ACTION=="add", ENV{NM_UNMANAGED}="1"

EOF

# Enable PTP with chrony for accurate time sync
echo -e "\nrefclock PHC /dev/ptp0 poll 3 dpoll -2 offset 0\n" >> /etc/chrony.conf
sed -i 's/makestep.*$/makestep 1.0 -1/g' /etc/chrony.conf
grep -q '^makestep' /etc/chrony.conf || echo 'makestep 1.0 -1' >> /etc/chrony.conf

# Enable DNS cache
# Comment this by default due to "DNSSEC validation failed" issues
#sed -i 's/hosts:\s*files dns myhostname/hosts:      files resolve dns myhostname/' /etc/nsswitch.conf

# Update dnf configuration
echo "http_caching=packages" >> /etc/dnf/dnf.conf
dnf clean all

# Set tuned profile
echo "virtual-guest" > /etc/tuned/active_profile

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
cloud-init clean --logs

# Enable the Azure datasource
cat > /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<EOF
# This configuration file is used to connect to the Azure DS sooner
datasource_list: [ Azure ]
EOF

# Enable KVP for reporting provisioning telemetry
cat > /etc/cloud/cloud.cfg.d/10-azure-kvp.cfg <<EOF
# This configuration file enables provisioning telemetry reporting
reporting:
  logging:
    type: log
  telemetry:
    type: hyperv
EOF

# Write a systemd unit that will generate a dataloss warning file
cat > /etc/systemd/system/temp-disk-dataloss-warning.service <<EOF
# /etc/systemd/system/temp-disk-dataloss-warning.service

[Unit]
Description=Azure temporary resource disk dataloss warning file creation
After=multi-user.target cloud-final.service

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/temp-disk-dataloss-warning
StandardOutput=journal+console

[Install]
WantedBy=default.target
EOF

cat > /usr/local/sbin/temp-disk-dataloss-warning <<'EOFF'
#!/bin/sh
# /usr/local/sbin/temp-disk-dataloss-warning
# Write dataloss warning file on mounted Azure resource disk
AZURE_RESOURCE_DISK_PART1="/dev/disk/cloud/azure_resource-part1"

MOUNTPATH=$(grep "$AZURE_RESOURCE_DISK_PART1" /etc/fstab | tr '\t' ' ' | cut -d' ' -f2)
if [ -z "$MOUNTPATH" ]; then
echo "There is no mountpoint of $AZURE_RESOURCE_DISK_PART1 in /etc/fstab"
    exit 1
fi

if [ "$MOUNTPATH" = "none" ]; then
    echo "Mountpoint of $AZURE_RESOURCE_DISK_PART1 is not a path"
    exit 1
fi

if ! mountpoint -q "$MOUNTPATH"; then
    echo "$AZURE_RESOURCE_DISK_PART1 is not mounted at $MOUNTPATH"
    exit 1
fi

echo "Creating a dataloss warning file at ${MOUNTPATH}/DATALOSS_WARNING_README.txt"

cat > ${MOUNTPATH}/DATALOSS_WARNING_README.txt <<'EOF'
WARNING: THIS IS A TEMPORARY DISK.

Any data stored on this drive is SUBJECT TO LOSS and THERE IS NO WAY TO RECOVER IT.

Please do not use this disk for storing any personal or application data.

For additional details to please refer to the MSDN documentation at:
https://docs.microsoft.com/en-us/azure/virtual-machines/linux/managed-disks-overview#temporary-disk

EOF
EOFF
chmod 755 /usr/local/sbin/temp-disk-dataloss-warning
systemctl enable temp-disk-dataloss-warning

# Mount ephemeral disk at /mnt/resource
cat >> /etc/cloud/cloud.cfg.d/91-azure_datasource.cfg <<EOF
# By default, the Azure ephemeral temporary resource disk will be mounted
# by cloud-init at /mnt/resource.
#
# If the mountpoint of the temporary resource disk is customized
# to be something else other than the /mnt/resource default mountpoint,
# the RequiresMountsFor and ConditionPathIsMountPoint options of the following
# systemd unit should be updated accordingly:
#   temp-disk-swapfile.service (/etc/systemd/system/temp-disk-swapfile.service)
#
# For additional details on the temporary resource disk please refer to the MSDN documentation at:
# https://docs.microsoft.com/en-us/azure/virtual-machines/linux/managed-disks-overview#temporary-disk
mounts:
  - [ ephemeral0, /mnt/resource ]
EOF

if [[ -f /mnt/resource/swapfile ]]; then
    echo removing swapfile
    swapoff /mnt/resource/swapfile
    rm /mnt/resource/swapfile -f
fi

# Unset point release at the end of the post-install script so we can recreate a previous point release without current major version updates
sed -i -e 's/8.2.2004/$releasever/g' /etc/yum.repos.d/OpenLogicCentOS.repo
yum-config-manager --enable AppStream BaseOS extras

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

# Minimize actual disk usage by zeroing all unused space
dd if=/dev/zero of=/EMPTY bs=1M || echo "dd exit code $? is suppressed";
rm -f /EMPTY;
sync;

%end
