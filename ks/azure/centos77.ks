# Kickstart for provisioning a CentOS 7.7 Azure VM

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
url --url="http://olcentgbl.trafficmanager.net/centos/7.7.1908/os/x86_64/"
repo --name "os" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.7.1908/os/x86_64/" --cost=100
repo --name="updates" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.7.1908/updates/x86_64/" --cost=100
repo --name "extras" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.7.1908/extras/x86_64/" --cost=100
repo --name="openlogic" --baseurl="http://olcentgbl.trafficmanager.net/openlogic/7/openlogic/x86_64/"

# Root password
rootpw --plaintext "to_be_disabled"

# System services
services --enabled="sshd,waagent,NetworkManager"

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

# Enable kdump
%addon com_redhat_kdump --enable --reserve-mb=auto
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
cloud-init
cloud-utils-growpart
azure-repo-svc
-dracut-config-rescue

# Packages required for ADE (Azure Disk Encryption) ...
lsscsi
psmisc
lvm2
uuid
at
patch
cryptsetup
cryptsetup-reencrypt
pyparted
procps-ng
util-linux
# ... ADE

%end

%post --log=/var/log/anaconda/post-install.log

#!/bin/bash

# Disable the root account
usermod root -p '!!'

# Install the cloud-init from >= 7.8 to address the Azure byte swap issue
yum -y update cloud-init

# Install the sudo from >= 7.9 to address CVE-2021-3156
yum -y update sudo

# Set OL repos
curl -so /etc/yum.repos.d/OpenLogicCentOS.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/CentOS-Base-7.repo
curl -so /etc/yum.repos.d/OpenLogic.repo https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/azure/OpenLogic.repo

# Set options for proper repo fallback
yum-config-manager --setopt=retries=1 --setopt=\*.skip_if_unavailable=1 --save \*
sed -i -e 's/enabled=1/enabled=0/' /etc/yum/pluginconf.d/fastestmirror.conf

# Set these to the point release baseurls so we can recreate a previous point release without current major version updates
sed -i -e 's/$releasever/7.7.1908/g' /etc/yum.repos.d/OpenLogicCentOS.repo
yum-config-manager --disable base updates extras

# Import CentOS and OpenLogic public keys
curl -so /etc/pki/rpm-gpg/OpenLogic-GPG-KEY https://raw.githubusercontent.com/openlogic/AzureBuildCentOS/master/config/OpenLogic-GPG-KEY
rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-CentOS-7
rpm --import /etc/pki/rpm-gpg/OpenLogic-GPG-KEY

# Set the kernel cmdline
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0 scsi_mod.use_blk_mq=y crashkernel=auto"/g' /etc/default/grub

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
cat << EOF > /etc/modprobe.d/blacklist-floppy.conf
blacklist floppy
EOF

# Ensure Hyper-V drivers are built into initramfs
echo '# Ensure Hyper-V drivers are built into initramfs'	>> /etc/dracut.conf.d/azure.conf
echo -e "\nadd_drivers+=\" hv_vmbus hv_netvsc hv_storvsc\""	>> /etc/dracut.conf.d/azure.conf
echo '# Support booting Azure VMs off NVMe storage'		>> /etc/dracut.conf.d/azure.conf
echo -e "\nadd_drivers+=\" nvme pci-hyperv\""			>> /etc/dracut.conf.d/azure.conf
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
NM_CONTROLLED=yes
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
ln -s /dev/null /etc/udev/rules.d/75-persistent-net-generator.rules
rm -f /lib/udev/rules.d/75-persistent-net-generator.rules /etc/udev/rules.d/70-persistent-net.rules 2>/dev/null
rm -f /etc/udev/rules.d/70* 2>/dev/null
ln -s /dev/null /etc/udev/rules.d/80-net-name-slot.rules

# Disable NetworkManager handling of the SRIOV interfaces
cat <<EOF > /etc/udev/rules.d/68-azure-sriov-nm-unmanaged.rules

# Accelerated Networking on Azure exposes a new SRIOV interface to the VM.
# This interface is transparently bonded to the synthetic interface,
# so NetworkManager should just ignore any SRIOV interfaces.
SUBSYSTEM=="net", DRIVERS=="hv_pci", ACTION=="add", ENV{NM_UNMANAGED}="1"

EOF

# Change name of /dev/ptp to ensure uniqueness
cat <<EOF > /etc/udev/rules.d/99-azure-hyperv-ptp.rules

# Mellanox VFs also produce a /dev/ptp device. To avoid the conflict,
# we will rename the hyperv ptp interface "ptp_hyperv"
SUBSYSTEM=="ptp", ATTR{clock_name}=="hyperv", SYMLINK += "ptp_hyperv"

EOF

# Enable PTP with chrony for accurate time sync
echo -e "\nrefclock PHC /dev/ptp_hyperv poll 3 dpoll -2 offset 0\n" >> /etc/chrony.conf
sed -i 's/makestep.*$/makestep 1.0 -1/g' /etc/chrony.conf
grep -q '^makestep' /etc/chrony.conf || echo 'makestep 1.0 -1' >> /etc/chrony.conf

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable abrtd abrt-ccpp abrt-oops abrt-vmcore abrt-xorg

# Modify yum
echo "http_caching=packages" >> /etc/yum.conf
yum clean all

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

# Create a systemd unit that will handle swapfile
cat <<EOF > /etc/systemd/system/temp-disk-swapfile.service
# /etc/systemd/system/temp-disk-swapfile.service

[Unit]
Description=Swapfile management on mounted Azure temporary resource disk
After=network-online.target local-fs.target cloud-config.target
Wants=network-online.target local-fs.target cloud-config.target
Before=cloud-config.service

ConditionPathIsMountPoint=/mnt/resource
RequiresMountsFor=/mnt/resource

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/temp-disk-swapfile start
ExecStop=/usr/local/sbin/temp-disk-swapfile stop
RemainAfterExit=yes
StandardOutput=journal+console

[Install]
WantedBy=cloud-config.service
EOF

cat <<'EOF' > /usr/local/sbin/temp-disk-swapfile
#!/bin/sh
# Swapfile creation/deletion on mounted Azure temporary resource disk
# /usr/local/sbin/temp-disk-swapfile
# See https://docs.microsoft.com/en-us/azure/virtual-machines/linux/managed-disks-overview#temporary-disk

AZURE_RESOURCE_DISK_PART1="/dev/disk/cloud/azure_resource-part1"

start() {
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

    SWAPFILEPATH="${MOUNTPATH}/swapfile"

    if [ ! -f "$SWAPFILEPATH" ]; then
        (sh -c 'rm -f "$1" && umask 0066 && { fallocate -l "${2}M" "$1" || dd if=/dev/zero "of=$1" bs=1M "count=$2"; } && mkswap "$1" || { r=$?; rm -f "$1"; exit $r; }' 'setup_swap' "$SWAPFILEPATH" '2048') || (echo "Failed to create swapfile at $SWAPFILEPATH"; exit 1)
        echo "Successfully created swapfile at $SWAPFILEPATH"
    fi
    swapon "$SWAPFILEPATH" || (echo "Failed to activate swapfile at $SWAPFILEPATH"; exit 1)
    echo "Successfully activated swapfile at $SWAPFILEPATH"
}

stop() {
    FINDMNTDATA=$(findmnt -S "$AZURE_RESOURCE_DISK_PART1" 2> /dev/null | grep --color=never '/')
    if [ -z "$FINDMNTDATA" ]; then
        exit 0
    fi

    MOUNTPATH=$(echo "$FINDMNTDATA" | cut -d' ' -f1)
    if [ -z "$MOUNTPATH" ]; then
        exit 0
    fi

    (sh -c 'swapoff "$1" && rm -f "$1"' 'swapoff_rm_swap' "${MOUNTPATH}/swapfile") || true
}

case $1 in
  start|stop) "$1" ;;
esac

EOF

chmod 755 /usr/local/sbin/temp-disk-swapfile
systemctl disable temp-disk-swapfile

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
sed -i -e 's/7.7.1908/$releasever/g' /etc/yum.repos.d/OpenLogicCentOS.repo
yum-config-manager --enable base updates extras

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision
rm -f /etc/resolv.conf 2>/dev/null # workaround old agent bug

# Minimize actual disk usage by zeroing all unused space
dd if=/dev/zero of=/EMPTY bs=1M || echo "dd exit code $? is suppressed";
rm -f /EMPTY;
sync;

%end
