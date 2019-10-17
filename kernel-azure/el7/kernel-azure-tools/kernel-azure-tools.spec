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
Version:	4.3.1
Release:	1%{?dist}

Group:		System/Kernel
License:	GPLv2
Packager:	Microsoft Corporation
Vendor:		Microsoft Corporation

URL:		https://github.com/LIS/lis-next
Source0:	kernel-azure-tools-rh7.tar.gz

Provides:	kernel-azure-tools
Requires:	kernel-azure >= 3.10.0-957

BuildRoot:	%{_tmppath}/%{name}-%{version}-build
BuildArch:	x86_64

%description
This package contains utilities and daemons for the Microsoft Hyper-V environment.


%prep
%setup -n hv
cp tools/hv_get_dns_info hv_get_dns_info
cp tools/hv_get_dhcp_info hv_get_dhcp_info
cp tools/hv_set_ifconfig hv_set_ifconfig
cp tools/lsvmbus lsvmbus
cp tools/systemd/hv_fcopy_daemon.service hv_fcopy_daemon.service
cp tools/systemd/hv_kvp_daemon.service hv_kvp_daemon.service
cp tools/systemd/hv_vss_daemon.service hv_vss_daemon.service
cp tools/systemd/70-hv_fcopy.rules 70-hv_fcopy.rules
cp tools/systemd/70-hv_kvp.rules 70-hv_kvp.rules
cp tools/systemd/70-hv_vss.rules 70-hv_vss.rules
cp tools/68-azure-sriov-nm-unmanaged.rules 68-azure-sriov-nm-unmanaged.rules
cp tools/hv_kvp_daemon.c %_sourcedir/
cp tools/hv_vss_daemon.c %_sourcedir/
cp tools/hv_fcopy_daemon.c %_sourcedir/
set -- *
mkdir source
mv "$@" source/
#sed -i 's/#define HV_DRV_VERSION\t".*"/#define HV_DRV_VERSION\t"4.3.1"/g' source/include/linux/hv_compat.h

mkdir obj


%build
pushd source/tools
make
popd


%install
install -d -m0755 $RPM_BUILD_ROOT/lib/udev/rules.d/
install    -m0644 source/68-azure-sriov-nm-unmanaged.rules $RPM_BUILD_ROOT/lib/udev/rules.d/
install -d -m0755 $RPM_BUILD_ROOT/opt/files
install -d -m0755 $RPM_BUILD_ROOT/sbin
install    -m0755 source/lsvmbus $RPM_BUILD_ROOT/sbin/
install -d -m0755 $RPM_BUILD_ROOT/usr/sbin
install -d -m0755 $RPM_BUILD_ROOT/usr/sbin
install -d -m0755 $RPM_BUILD_ROOT/usr/libexec/hypervkvpd/
install    -m0755 source/hv_get_dns_info $RPM_BUILD_ROOT/usr/libexec/hypervkvpd/
install    -m0755 source/hv_get_dhcp_info $RPM_BUILD_ROOT/usr/libexec/hypervkvpd/
install    -m0755 source/hv_set_ifconfig $RPM_BUILD_ROOT/usr/libexec/hypervkvpd/
install    -m0755 source/tools/hv_kvp_daemon $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/tools/hv_fcopy_daemon $RPM_BUILD_ROOT/usr/sbin/
install    -m0755 source/tools/hv_vss_daemon $RPM_BUILD_ROOT/usr/sbin/
install -d -m0755 $RPM_BUILD_ROOT/lib/systemd/system/
install    -m0644 source/hv_kvp_daemon.service $RPM_BUILD_ROOT/lib/systemd/system/hv_kvp_daemon.service
install    -m0644 source/hv_fcopy_daemon.service $RPM_BUILD_ROOT/lib/systemd/system/hv_fcopy_daemon.service
install    -m0644 source/hv_vss_daemon.service $RPM_BUILD_ROOT/lib/systemd/system/hv_vss_daemon.service
install -d -m0755 $RPM_BUILD_ROOT/usr/lib/udev/rules.d/
install    -m0644 source/70-hv_kvp.rules $RPM_BUILD_ROOT/usr/lib/udev/rules.d/70-hv_kvp.rules
install    -m0644 source/70-hv_fcopy.rules $RPM_BUILD_ROOT/usr/lib/udev/rules.d/70-hv_fcopy.rules
install    -m0644 source/70-hv_vss.rules $RPM_BUILD_ROOT/usr/lib/udev/rules.d/70-hv_vss.rules


%post
echo "Starting KVP Daemon...."
systemctl daemon-reload
systemctl enable hv_kvp_daemon.service > /dev/null 2>&1
#systemctl start hv_kvp_daemon

echo "Starting VSS Daemon...."
systemctl enable hv_vss_daemon.service > /dev/null 2>&1
#systemctl start hv_vss_daemon

echo "Starting FCOPY Daemon...."
systemctl enable hv_fcopy_daemon.service > /dev/null 2>&1
#systemctl start hv_fcopy_daemon


%preun
if [ $1 -eq 0 ]; then # package is being erased, not upgraded
    echo "Removing Package.."
    echo "Stopping KVP Daemon...."
    systemctl stop hv_kvp_daemon
    echo "Stopping FCOPY Daemon...."
    systemctl stop hv_fcopy_daemon
    echo "Stopping VSS Daemon...."
    systemctl stop hv_vss_daemon
fi


%clean
rm -rf $RPM_BUILD_ROOT


%files
%defattr(0644, root, root)
/lib/udev/rules.d/68-azure-sriov-nm-unmanaged.rules
/usr/lib/udev/rules.d/70-hv_vss.rules
/usr/lib/udev/rules.d/70-hv_kvp.rules
/usr/lib/udev/rules.d/70-hv_fcopy.rules
/lib/systemd/system/hv_fcopy_daemon.service
/lib/systemd/system/hv_kvp_daemon.service
/lib/systemd/system/hv_vss_daemon.service
%defattr(0755, root, root)
/usr/sbin/hv_kvp_daemon
/usr/sbin/hv_vss_daemon
/usr/sbin/hv_fcopy_daemon
/usr/libexec/hypervkvpd/hv_get_dns_info
/usr/libexec/hypervkvpd/hv_get_dhcp_info
/usr/libexec/hypervkvpd/hv_set_ifconfig
/sbin/lsvmbus
/opt/files/


%changelog
* Wed May 1 2019 - Stephen A. Zarkos <stephen.zarkos@microsoft.com>
- Update to LIS 4.3.1

* Wed Aug 8 2018 - Stephen A. Zarkos <stephen.zarkos@microsoft.com>
- Initial release for kernel-azure package from the CentOS Virt SIG

