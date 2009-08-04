#
# spec file for package build-compare (Version 2009.08.04)
#
# Copyright (c) 2009 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

# norootforbuild


Name:           build-compare
License:        GPL v2 or later
Group:          Development/Tools/Building
AutoReqProv:    on
Summary:        Build Result Compare Script
Version:        2009.08.04
Release:        1
Source:         same-build-result.sh
Source1:        rpm-check.sh
Source2:        COPYING
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch:      noarch

%description
This package contains scripts to find out if the build result differs
to a former build.



%prep
mkdir $RPM_BUILD_DIR/%name-%version
%setup -T 0 -D

%build

%install
mkdir -p $RPM_BUILD_ROOT/usr/lib/build/ $RPM_BUILD_ROOT/%_defaultdocdir/%name
install -m 0755 %SOURCE0 %SOURCE1 $RPM_BUILD_ROOT/usr/lib/build/
install -m 0644 %SOURCE2 $RPM_BUILD_ROOT/%_defaultdocdir/%name/

%files
%defattr(-,root,root)
%doc %_defaultdocdir/%name
/usr/lib/build

%changelog
