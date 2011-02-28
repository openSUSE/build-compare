#!/bin/bash
#
# Copyright (c) 2009, 2010 SUSE Linux Product GmbH, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Coolo
# Enhanced by Andreas Jaeger

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

oldrpm=`readlink -f $1`
newrpm=`readlink -f $2`


# For source RPMs, we can just check the metadata in the spec file
# if those are not the same, the source RPM has changed and therefore 
# the resulting files are needed.

cmp_spec $1 $2
RES=$?
case $RES in
  0)
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

dir=`mktemp -d`
unrpm $oldrpm $dir/old
unrpm $newrpm $dir/new
cd $dir

check_single_file()
{ 
  local file=$1
  case $file in
    *.spec)
       sed -i -e "s,Release:.*$release1,Release: @RELEASE@," old/$file
       sed -i -e "s,Release:.*$release2,Release: @RELEASE@," new/$file
       if ! cmp -s old/$file new/$file; then
         echo "$file differs (spec file)"
         diff -u old/$file new/$file | head -n 20
         return 1
       fi
       return 0
       ;;
    *)
       echo "$file differs"
       # Nothing else should be changed
       ;;
   esac
   return 1
}

ret=0
for file in $files; do
   if ! check_single_file $file; then
       ret=1
       if test -z "$check_all"; then
           break
       fi
   fi
done

rm -r $dir
exit $ret
