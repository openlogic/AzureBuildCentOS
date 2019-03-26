# Kickstart for provisioning a CentOS 7.6 Azure HPC (SR-IOV) VM

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
url --url="http://olcentgbl.trafficmanager.net/centos/7.6.1810/os/x86_64/"
repo --name "os" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.6.1810/os/x86_64/" --cost=100
repo --name="updates" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.6.1810/updates/x86_64/" --cost=100
repo --name "extras" --baseurl="http://olcentgbl.trafficmanager.net/centos/7.6.1810/extras/x86_64/" --cost=100
repo --name="openlogic" --baseurl="http://olcentgbl.trafficmanager.net/openlogic/7/openlogic/x86_64/"

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
@development
ntp
cifs-utils
sudo
python-pyasn1
parted
WALinuxAgent
hypervkvpd
azure-repo-svc
-dracut-config-rescue
selinux-policy-devel
kernel-headers
nfs-utils
numactl
numactl-devel
libxml2-devel
byacc
environment-modules
python-devel
python-setuptools
gtk2
atk
cairo
tcl
tk
m4
glibc-devel
glibc-static
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
sed -i 's/^\(GRUB_CMDLINE_LINUX\)=".*"$/\1="console=tty1 console=ttyS0,115200n8 earlyprintk=ttyS0,115200 rootdelay=300 net.ifnames=0 scsi_mod.use_blk_mq=y"/g' /etc/default/grub

# Enable grub serial console
echo 'GRUB_SERIAL_COMMAND="serial --speed=115200 --unit=0 --word=8 --parity=no --stop=1"' >> /etc/default/grub
sed -i 's/^GRUB_TERMINAL_OUTPUT=".*"$/GRUB_TERMINAL="serial console"/g' /etc/default/grub

# Blacklist the nouveau driver
cat << EOF > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
EOF

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

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable wpa_supplicant
systemctl disable abrtd
systemctl disable firewalld

# Update memory limits
cat << EOF >> /etc/security/limits.conf
*               hard    memlock         unlimited
*               soft    memlock         unlimited
*               soft    nofile          65535
*               soft    nofile          65535
EOF

# Disable GSS proxy
sed -i 's/GSS_USE_PROXY="yes"/GSS_USE_PROXY="no"/g' /etc/sysconfig/nfs

# Enable reclaim mode
echo "vm.zone_reclaim_mode = 1" >> /etc/sysctl.conf
sysctl -p

# Install Mellanox OFED
mkdir -p /tmp/mlnxofed
cd /tmp/mlnxofed
wget http://www.mellanox.com/downloads/ofed/MLNX_OFED-4.5-1.0.1.0/MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz
tar zxvf MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64.tgz

KERNEL=( $(rpm -q kernel | sed 's/kernel\-//g') )
KERNEL=${KERNEL[-1]}
yum install -y kernel-devel-${KERNEL}
./MLNX_OFED_LINUX-4.5-1.0.1.0-rhel7.6-x86_64/mlnxofedinstall --kernel $KERNEL --kernel-sources /usr/src/kernels/${KERNEL} --add-kernel-support --skip-repo

sed -i 's/LOAD_EIPOIB=no/LOAD_EIPOIB=yes/g' /etc/infiniband/openib.conf
/etc/init.d/openibd restart
cd && rm -rf /tmp/mlnxofed

# Configure WALinuxAgent
sed -i -e 's/# OS.EnableRDMA=y/OS.EnableRDMA=y/g' /etc/waagent.conf
systemctl enable waagent

# Install gcc 8.2
mkdir -p /tmp/setup-gcc
cd /tmp/setup-gcc

wget ftp://gcc.gnu.org/pub/gcc/infrastructure/gmp-6.1.0.tar.bz2
tar -xvf gmp-6.1.0.tar.bz2
cd ./gmp-6.1.0
./configure && make -j 8 && make install
cd ..

wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpfr-3.1.4.tar.bz2
tar -xvf mpfr-3.1.4.tar.bz2
cd mpfr-3.1.4
./configure && make -j 8 && make install
cd ..

wget ftp://gcc.gnu.org/pub/gcc/infrastructure/mpc-1.0.3.tar.gz
tar -xvf mpc-1.0.3.tar.gz
cd mpc-1.0.3
./configure && make -j 8 && make install
cd ..

# install gcc 8.2
wget https://ftp.gnu.org/gnu/gcc/gcc-8.2.0/gcc-8.2.0.tar.gz
tar -xvf gcc-8.2.0.tar.gz
cd gcc-8.2.0
./configure --disable-multilib --prefix=/opt/gcc-8.2.0 && make -j 8 && make install
cd && rm -rf /tmp/setup-gcc


cat << EOF >> /usr/share/Modules/modulefiles/gcc-8.2.0
#%Module 1.0
#
#  GCC 8.2.0
#

prepend-path    PATH            /opt/gcc-8.2.0/bin
prepend-path    LD_LIBRARY_PATH /opt/gcc-8.2.0/lib64
setenv          CC              /opt/gcc-8.2.0/bin/gcc
setenv          GCC             /opt/gcc-8.2.0/bin/gcc
EOF

# Load gcc-8.2.0
export PATH=/opt/gcc-8.2.0/bin:$PATH
export LD_LIBRARY_PATH=/opt/gcc-8.2.0/lib64:$LD_LIBRARY_PATH
set CC=/opt/gcc-8.2.0/bin/gcc
set GCC=/opt/gcc-8.2.0/bin/gcc

# Install MPIs
INSTALL_PREFIX=/opt
mkdir -p /tmp/mpi
cd /tmp/mpi

# MVAPICH2 2.3
wget http://mvapich.cse.ohio-state.edu/download/mvapich/mv2/mvapich2-2.3.tar.gz
tar -xvf mvapich2-2.3.tar.gz
cd mvapich2-2.3
./configure --prefix=${INSTALL_PREFIX}/mvapich2-2.3 --enable-g=none --enable-fast=yes && make -j 8 && make install
cd ..

# UCX 1.5.0
wget https://github.com/openucx/ucx/releases/download/v1.5.0/ucx-1.5.0.tar.gz
tar -xvf ucx-1.5.0.tar.gz 
cd ucx-1.5.0
./contrib/configure-release --prefix=${INSTALL_PREFIX}/ucx-1.5.0 && make -j 8 && make install
cd ..

# HPC-X v2.3.0
cd ${INSTALL_PREFIX}
wget http://www.mellanox.com/downloads/hpc/hpc-x/v2.3/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64.tbz
tar -xvf hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64.tbz
HPCX_PATH=${INSTALL_PREFIX}/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64
HCOLL_PATH=${HPCX_PATH}/hcoll
rm -rf hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64.tbz
cd /tmp/mpi

# OpenMPI 4.0.0
wget https://download.open-mpi.org/release/open-mpi/v4.0/openmpi-4.0.0.tar.gz
tar -xvf openmpi-4.0.0.tar.gz
cd openmpi-4.0.0
./configure --prefix=${INSTALL_PREFIX}/openmpi-4.0.0 --with-ucx=${INSTALL_PREFIX}/ucx-1.5.0 --enable-mpirun-prefix-by-default && make -j 8 && make install
cd ..

# MPICH 3.3
wget http://www.mpich.org/static/downloads/3.3/mpich-3.3.tar.gz
tar -xvf mpich-3.3.tar.gz
cd mpich-3.3
./configure --prefix=${INSTALL_PREFIX}/mpich-3.3 --with-ucx=${INSTALL_PREFIX}/ucx-1.5.0 --with-hcoll=${HCOLL_PATH} --enable-g=none --enable-fast=yes --with-device=ch4:ucx   && make -j 8 && make install 
cd ..

# Intel MPI 2019 (update 2)
CFG="IntelMPI-v2019.x-silent.cfg"
wget http://registrationcenter-download.intel.com/akdlm/irc_nas/tec/15040/l_mpi_2019.2.187.tgz
wget https://raw.githubusercontent.com/szarkos/AzureBuildCentOS/master/config/azure/${CFG}
tar -xvf l_mpi_2019.2.187.tgz
cd l_mpi_2019.2.187
./install.sh --silent /tmp/mpi/${CFG}
cd ..

cd && rm -rf /tmp/mpi

# Setup module files for MPIs
mkdir -p /usr/share/Modules/modulefiles/mpi/

# HPC-X
cat << EOF >> /usr/share/Modules/modulefiles/mpi/hpcx-v2.3.0
#%Module 1.0
#
#  HPCx 2.3.0
#
conflict        mpi
prepend-path    PATH            /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/bin
prepend-path    PATH            /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64
prepend-path    LD_LIBRARY_PATH /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/lib
prepend-path    MANPATH         /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/share/man
setenv          MPI_BIN         /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/bin
setenv          MPI_INCLUDE     /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/include
setenv          MPI_LIB         /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/lib
setenv          MPI_MAN         /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi/share/man
setenv          MPI_HOME        /opt/hpcx-v2.3.0-gcc-MLNX_OFED_LINUX-4.5-1.0.1.0-redhat7.6-x86_64/ompi
EOF

# MPICH
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mpich-3.3
#%Module 1.0
#
#  MPICH 3.3
#
conflict        mpi
prepend-path    PATH            /opt/mpich-3.3/bin
prepend-path    LD_LIBRARY_PATH /opt/mpich-3.3/lib
prepend-path    MANPATH         /opt/mpich-3.3/share/man
setenv          MPI_BIN         /opt/mpich-3.3/bin
setenv          MPI_INCLUDE     /opt/mpich-3.3/include
setenv          MPI_LIB         /opt/mpich-3.3/lib
setenv          MPI_MAN         /opt/mpich-3.3/share/man
setenv          MPI_HOME        /opt/mpich-3.3
EOF

# MVAPICH2
cat << EOF >> /usr/share/Modules/modulefiles/mpi/mvapich2-2.3
#%Module 1.0
#
#  MVAPICH2 2.3
#
conflict        mpi
prepend-path    PATH            /opt/mvapich2-2.3/bin
prepend-path    LD_LIBRARY_PATH /opt/mvapich2-2.3/lib
prepend-path    MANPATH         /opt/mvapich2-2.3/share/man
setenv          MPI_BIN         /opt/mvapich2-2.3/bin
setenv          MPI_INCLUDE     /opt/mvapich2-2.3/include
setenv          MPI_LIB         /opt/mvapich2-2.3/lib
setenv          MPI_MAN         /opt/mvapich2-2.3/share/man
setenv          MPI_HOME        /opt/mvapich2-2.3
EOF

# OpenMPI
cat << EOF >> /usr/share/Modules/modulefiles/mpi/openmpi-4.0.0
#%Module 1.0
#
#  OpenMPI 4.0.0
#
conflict        mpi
prepend-path    PATH            /opt/openmpi-4.0.0/bin
prepend-path    LD_LIBRARY_PATH /opt/openmpi-4.0.0/lib
prepend-path    MANPATH         /opt/openmpi-4.0.0/share/man
setenv          MPI_BIN         /opt/openmpi-4.0.0/bin
setenv          MPI_INCLUDE     /opt/openmpi-4.0.0/include
setenv          MPI_LIB         /opt/openmpi-4.0.0/lib
setenv          MPI_MAN         /opt/openmpi-4.0.0/share/man
setenv          MPI_HOME        /opt/openmpi-4.0.0
EOF


# Modify yum
echo "http_caching=packages" >> /etc/yum.conf
yum history sync
yum clean all

# Set tuned profile
echo "virtual-guest" > /etc/tuned/active_profile

# Deprovision and prepare for Azure
/usr/sbin/waagent -force -deprovision

%end
