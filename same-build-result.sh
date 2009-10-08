#!/bin/bash
#
# Copyright (c) 2009 SUSE Linux Product Gmbh, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Adrian Schroeter <adrian@suse.de>
#
# The script decides if the new build differes from the former one,
# using rpm-check.sh.
# The script is called as part of the build process as:
# /usr/lib/build/same-build-result.sh /.build.oldpackages /usr/src/packages/RPMS /usr/src/packages/SRPMS

CMPSCRIPT=${0%/*}/rpm-check.sh

OLDDIR="$1"
shift
NEWDIRS="$*"


echo "$CMPSCRIPT"

if [ ! -d "$OLDDIR" ]; then
  echo "No valid directory with old build result given !"
  exit 1
fi
if [ -z "$NEWDIRS" ]; then
  echo "No valid directory with new build result given !"
  exit 1
fi

if test `find $NEWDIRS -name *.rpm  | wc -l` != `find $OLDDIR -name *.rpm  | wc -l`; then
   echo "different number of subpackages"
   find $OLDDIR $NEWDIRS -name *.rpm
   exit 1
fi

osrpm=$(find "$OLDDIR" -name \*src.rpm)
nsrpm=$(find $NEWDIRS -name \*src.rpm)

if test ! -f "$osrpm"; then
  echo no old source rpm in $OLDDIR
  exit 1
fi

if test ! -f "$nsrpm"; then
  echo no new source rpm in $NEWDIRS
  exit 1
fi

echo "compare $osrpm $nsrpm"
bash $CMPSCRIPT "$osrpm" "$nsrpm" || exit 1

# technically we should not all exclude all -32bit but filter for different archs, but it would be better
# if this script ran earlier in the build
# sort the rpms so that both lists have the same order
# problem: a package can contain both noarch and arch subpackages, so we have to 
# take care of proper sorting of NEWRPMS, e.g. noarch/x.rpm and x86_64/w.rpm since OLDRPMS 
# has all the packages in a single directory and would sort this as w.rpm, x.rpm.
OLDRPMS=($(find "$OLDDIR" -name \*rpm -a ! -name \*src.rpm|sort|grep -v -- -32bit|grep -v -- -64bit|grep -v -- -x86))
NEWRPMS=($(find $NEWDIRS -name \*rpm -a ! -name \*src.rpm|sort --field-separator=/ --key=7|grep -v -- -32bit|grep -v -- -64bit|grep -v -- -x86))

rpmqp='rpm -qp --qf %{NAME} --nodigest --nosignature '
for opac in ${OLDRPMS[*]}; do
  npac=${NEWRPMS[0]}
  NEWRPMS=(${NEWRPMS[@]:1}) # shift
  echo compare "$opac" "$npac"
  oname=`$rpmqp $opac`
  nname=`$rpmqp $npac`
  if test "$oname" != "$nname"; then
     echo "names differ: $oname $nname"
     exit 1
  fi
  bash $CMPSCRIPT "$opac" "$npac" || exit 1
done

if [ -n "${NEWRPMS[0]}" ]; then
  echo additional new package
  exit 1
fi

echo compare validated built as identical !
exit 0

