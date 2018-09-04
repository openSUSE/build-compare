#
# spec file for package stringtext
#
# Copyright (c) 2018 SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

Name:           stringtext
Version:        1
Release:        0
License:        MIT
Summary:        build-compare test rpm
%?metadata

%description
build-compare test rpm

%build
%{outcmd}

%files
%defattr(-,root,root)
%doc %{outfile}
