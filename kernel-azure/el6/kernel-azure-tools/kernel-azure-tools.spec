# Spec file for package kernel-azure-tools
#
# Copyright (c) 2010 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:		kernel-azure-tools
Summary:	Microsoft Hyper-v utilities
Version:	4.2.6
Release:	1%{?dist}

Group:		System/Kernel
License:	GPLv2
Packager:	Microsoft Corporation
Vendor:		Microsoft Corporation

URL:		https://github.com/LIS/lis-next
Source0:	kernel-azure-tools-rh6.tar.gz
Source1:	hypervkvpd
Source2:	hypervvssd
Source3:	hypervfcopy
Source4:	100-balloon.rules

Provides:	kernel-azure-tools
Requires:	kernel-azure >= 2.6.32-754

BuildRoot:	%{_tmppath}/%{name}-%{version}-build
BuildArch:	x86_64

%description
This package contains utilities and daemons for the Microsoft Hyper-V environment.


%prep
%setup -n hv
cp tools/hv_get_dns_info.sh hv_get_dns_info
cp tools/hv_get_dhcp_info.sh hv_get_dhcp_info
cp tools/hv_set_ifconfig.sh hv_set_ifconfig
cp tools/lsvmbus lsvmbus
cp tools/hv_kvp_daemon.c %_sourcedir/
cp tools/hv_vss_daemon.c %_sourcedir/
cp tools/hv_fcopy_daemon.c %_sourcedir/
set -- *
mkdir source
mv "$@" source/
sed -i 's/#define HV_DRV_VERSION\t".*"/#define HV_DRV_VERSION\t"4.2.6"/g' source/include/linux/hv_compat.h

mkdir obj


%build
pushd source/tools
make
popd


%install
install -d -m0755 $RPM_BUILD_ROOT/etc/udev/rules.d/
install -d -m0755 $RPM_BUILD_ROOT/opt/files
install -d -m0755 $RPM_BUILD_ROOT/sbin
install    -m0755 source/lsvmbus $RPM_BUILD_ROOT/sbin/
install -d -m0755 $RPM_BUILD_ROOT/usr/sbin
install    -m0755 source/hv_get_dns_info $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/hv_get_dhcp_info $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/hv_set_ifconfig $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/tools/hv_kvp_daemon $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/tools/hv_fcopy_daemon $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/tools/hv_vss_daemon $RPM_BUILD_ROOT/usr/sbin/
install -d -m0755 $RPM_BUILD_ROOT/etc/init.d
install    -m0755 %{S:1} $RPM_BUILD_ROOT/etc/init.d/hv_kvp_daemon
install    -m0755 %{S:2} $RPM_BUILD_ROOT/etc/init.d/hv_vss_daemon
install    -m0755 %{S:3} $RPM_BUILD_ROOT/etc/init.d/hv_fcopy_daemon
install    -m0755 %{S:4} $RPM_BUILD_ROOT/etc/udev/rules.d/100-balloon.rules


%post
/sbin/chkconfig --add hv_kvp_daemon
echo "Adding KVP Daemon to Chkconfig...."
/etc/init.d/hv_kvp_daemon start >/dev/null
echo "Starting KVP Daemon...."

/sbin/chkconfig --add hv_vss_daemon
echo "Adding VSS Daemon to Chkconfig...."
/etc/init.d/hv_vss_daemon start >/dev/null
echo "Starting VSS Daemon...."

/sbin/chkconfig --add hv_fcopy_daemon
echo "Adding FCOPY Daemon to Chkconfig...."
/etc/init.d/hv_fcopy_daemon start >/dev/null
echo "Starting FCOPY Daemon...."


%preun
if [ $1 -eq 0 ]; then # package is being erased, not upgraded
    echo "Removing Package.."
    /sbin/service hv_kvp_daemon stop > /dev/null 2>&1
    echo "Stopping KVP Daemon...."
    /sbin/chkconfig --del hv_kvp_daemon
    echo "Deleting KVP Daemon from Chkconfig...."
    /sbin/service hv_vss_daemon stop > /dev/null 2>&1
    echo "Stopping VSS Daemon...."
    /sbin/chkconfig --del hv_vss_daemon
    echo "Deleting VSS Daemon from Chkconfig...."
    /sbin/service hv_fcopy_daemon stop > /dev/null 2>&1
    echo "Stopping FCOPY Daemon...."
    /sbin/chkconfig --del hv_fcopy_daemon
    echo "Deleting FCOPY Daemon from Chkconfig...."

fi


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(0755,root,root)
/etc/udev/rules.d/100-balloon.rules
/etc/init.d/hv_kvp_daemon
/usr/sbin/hv_kvp_daemon
/etc/init.d/hv_vss_daemon
/usr/sbin/hv_vss_daemon
/etc/init.d/hv_fcopy_daemon
/usr/sbin/hv_fcopy_daemon
/usr/sbin/hv_get_dns_info
/usr/sbin/hv_get_dhcp_info
/usr/sbin/hv_set_ifconfig
/opt/files/
/sbin/lsvmbus


%changelog
* Wed Aug 8 2018 - Stephen A. Zarkos <stephen.zarkos@microsoft.com>
- Initial release for kernel-azure package from the CentOS Virt SIG


