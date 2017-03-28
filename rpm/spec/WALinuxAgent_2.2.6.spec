#===============================================================================
# Name: walinuxagent.spec
#-------------------------------------------------------------------------------
# Purpose : RPM Spec file for Python script packaging
# Version : 2.2.6
# Created : April 20 2012
#===============================================================================

%define name WALinuxAgent
%define version 2.2.6
%define unmangled_version 2.2.6
%define unmangled_version 2.2.6
%define release 1

%if 0%{?rhel} < 7
%global initsys sysV
%else
%global initsys systemd
%endif

Summary:   The Microsoft Azure Linux Agent
Name:      %{name}
Version:   %{version}
Release:   %{release}%{?dist}
Source0:   %{name}-%{unmangled_version}.tar.gz
License:   Apache License Version 2.0
Group:     Development/Libraries
BuildRoot: %{_tmppath}/%{name}-%{version}-%{release}-buildroot
Prefix:    %{_prefix}
BuildArch: noarch
Vendor:    Microsoft Corporation <walinuxagent@microsoft.com>
Url:       https://github.com/Azure/WALinuxAgent

Requires: util-linux
Requires: net-tools
Requires: openssh
Requires: openssh-server
Requires: openssl
Requires: parted
Requires: python-pyasn1

%if %{initsys} == systemd
Requires:       NetworkManager
%else
%if %{initsys} == sysV
Conflicts:      NetworkManager
%endif
%endif

%if %{initsys} == systemd
BuildRequires:   systemd
Requires(pre):  systemd
Requires(post):  systemd
Requires(preun): systemd
Requires(postun): systemd
%else
%if %{initsys} == sysv
Requires(post):  chkconfig
Requires(preun): chkconfig
Requires(preun): initscripts
Requires(postun): initscripts
%endif
%endif

%description
The Azure Linux Agent supports the provisioning and running of Linux
VMs in the Azure cloud. This package should be installed on Linux disk
images that are built to run in the Azure environment.


%prep
%setup -n %{name}-%{unmangled_version} -n %{name}-%{unmangled_version}

%build
python setup.py build

%install
python setup.py install --single-version-externally-managed -O1 --root=$RPM_BUILD_ROOT --record=INSTALLED_FILES

%clean
rm -rf $RPM_BUILD_ROOT

%post
%if %{initsys} == systemd
%systemd_post waagent.service
%else
%if %{initsys} == sysV
/sbin/chkconfig --add waagent
%endif
%endif

%preun
%if %{initsys} == systemd
%systemd_preun waagent.service
%else
%if %{initsys} == sysV
if [ $1 = 0 ]; then
        /sbin/service waagent stop >/dev/null 2>&1
        /sbin/chkconfig --del waagent
fi
%endif
%endif

%postun
%if %{initsys} == systemd
%systemd_postun_with_restart waagent.service
%else
%if %{initsys} == sysV
if [ "$1" -ge "1" ]; then
        /sbin/service waagent restart >/dev/null 2>&1 || :
fi
%endif
%endif

%files -f INSTALLED_FILES
%{python_sitelib}/*
%config(noreplace) %{_sysconfdir}/waagent.conf
%defattr(-,root,root)

%changelog
* Mon Mar 28 2017 - mike.hagan@roguewave.com
- Updated version to 2.2.6 for release
* Mon Feb  6 2017 - mike.hagan@roguewave.com
- Updated version to 2.2.4 for release
* Fri Dec 16 2016 - mike.hagan@roguewave.com
- Updated version to 2.2.2 for release
* Fri Sep 30 2016 - walinuxagent@microsoft.com
- Updated version to 2.2.0 for release
