#!/bin/bash
#
# Copyright (c) 2009, 2010 SUSE Linux Product GmbH, Germany.
# Copyright (c) 2022 SUSE LLC
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Kulow
# Enhanced by Andreas Jaeger and Dirk Müller

# Compare two source RPMs

FUNCTIONS=${0%/*}/functions.sh

check_all=
case $1 in
  -a | --check-all)
    check_all=1
    shift
esac

if test "$#" != 2; then
  echo "usage: $0 [-a|--check-all] old.rpm new.rpm"
  exit 1
fi

source $FUNCTIONS

oldrpm=$(readlink -f $1)
newrpm=$(readlink -f $2)
rename_script=

# For source RPMs, we can just check the metadata in the spec file
# if those are not the same, the source RPM has changed and therefore 
# the resulting files are needed.

cmp_rpm_meta "$rename_script" "$oldrpm" "$newrpm"
RES=$?
case $RES in
  0)
     echo "RPM meta information is identical"
     exit 0
     ;;
  1)
     echo "RPM meta information is different"
     exit 1
     ;;
  2)
     ;;
  *)
     echo "Wrong exit code!"
     exit 1
     ;;
esac

# Now check that only the spec file has a changed release number and
# nothing else

dir=$(mktemp -d)
unpackage $oldrpm $dir/old &
unpackage $newrpm $dir/new &
cd $dir
wait

check_single_file()
{ 
  local file=$1
  case $file in
    *.spec)
      sed -i -e 's,^Release:.*$,Release: @RELEASE@,' old/$file
      sed -i -e 's,^Release:.*$,Release: @RELEASE@,' new/$file
      diff --speed-large-files -su0 old/$file new/$file | head -n 20
      return "${PIPESTATUS[0]}"
      ;;
    *)
      echo "$file differs"
      # Nothing else should be changed
      ;;
  esac
  return 1
}

ret=0
for file in "${files[@]}"; do
  if ! check_single_file $file; then
    ret=1
    if test -z "$check_all"; then
      break
    fi
  fi
done

rm -rf $dir
exit $ret
# vim: tw=666 ts=2 shiftwidth=2 et
