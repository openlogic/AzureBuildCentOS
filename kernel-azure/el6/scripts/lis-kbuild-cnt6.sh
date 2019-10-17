#!/bin/bash

lis="4.3.3"
krepo="6.10"
kversion=$( curl -s "http://vault.centos.org/${krepo}/updates/Source/SPackages/" | \
            grep "kernel-2.6.32-754" | \
            sed 's/.*<a href="//' | sed 's/">.*//' | sort -V | tail -1 | sed 's/\.src\.rpm//' | sed 's/kernel-//' )
kbasever=$( echo -n $kversion | sed -r 's/\.[0-9]*\.[0-9]*\.el[6-8]//' )

topdir="/mnt/resource/CENTOS-KERNEL"
cd $topdir

echo "Building for LIS version $lis and kernel version $kversion ..."

# Download the latest LIS source
# Output example: lis-next-4.2.5
echo "Downloading v${lis}.tar.gz..."
curl -sL https://github.com/LIS/lis-next/archive/${lis}.tar.gz | tar zx


# Download the latest CentOS6 kernel SRPM
echo "Downloading kernel-${kversion}.src.rpm..."
curl -so ${topdir}/kernel-${kversion}.src.rpm "http://vault.centos.org/${krepo}/updates/Source/SPackages/kernel-${kversion}.src.rpm"
echo "Checking GPG signature for kernel-${kversion}.src.rpm..."
rpm -K kernel-${kversion}.src.rpm
if [ "$?" -ne "0" ]; then
	echo "Unable to verify signature of kernel-${kversion}.src.rpm"
	exit
fi


# Extract the SRPM
echo "Extracting kernel-${kversion}.src.rpm..."
rm -rf rpmbuild 2>/dev/null
mkdir -p ${topdir}/rpmbuild/{BUILD,BUILDROOT,RPMS,SOURCES,SPECS,SRPMS}
rpm -i ${topdir}/kernel-${kversion}.src.rpm 2>&1 | grep -v exist


# Extract the kernel source
echo "Setting up kernel source trees..."

cp rpmbuild/SOURCES/linux-${kversion}.tar.bz2 .
tar -jxf ./linux-${kversion}.tar.bz2
mv linux-${kversion} linux-${kversion}.orig

cp rpmbuild/SOURCES/linux-${kversion}.tar.bz2 .
tar -jxf ./linux-${kversion}.tar.bz2
mv linux-${kversion} linux-${kversion}.lis


# Copy files from lis-next-${lis} to linux-${kversion}.lis
# Fixme: checkout this script and other need things (makefile/kconfig)
# Fixme: file should accept parameters, i.e. "./copy-files.sh <LISVER> <KERNVER>"
echo "Copying LIS files to source tree..."
./copy-files.sh "$kversion" "lis-next-${lis}"

# Create the patch
echo "Creating the LIS patch, copying to SOURCES..."
diff -Naur linux-${kversion}.orig linux-${kversion}.lis 2>/dev/null > patches/LIS-${lis}_linux-${kbasever}.patch
cp patches/LIS-${lis}_linux-${kbasever}.patch ./rpmbuild/SOURCES/


# Patch spec file
echo "Patching spec file..."
cd ${topdir}/rpmbuild/SPECS

cp ${topdir}/patches/LIS-kernel-azure.spec.patch-orig ./LIS-kernel-azure.spec.patch
sed -i "s/LIS\.patch/LIS-${lis}_linux-${kbasever}\.patch/g" ./LIS-kernel-azure.spec.patch

cp kernel.spec kernel.spec.orig
patch -p0 < ./LIS-kernel-azure.spec.patch


# Patch kernel build config
#echo "Patching kernel build config..."
#cd ${topdir}/rpmbuild/SOURCES
#patch -p0 < ${topdir}/patches/config-x86_64-generic-rhel.patch

# Build the kernel
echo -e "Begin building kernel...\n\n"
cd ..
rpmbuild -ba ./SPECS/kernel.spec


# Cleanup
echo "Cleaning up files..."
cd ${topdir}
rm -f linux-${kversion}.tar.xz
rm -rf linux-${kversion}*
rm -rf lis-next-${lis}
rm kernel-${kversion}.src.rpm
