#!/bin/bash
#
# Copyright (c) 2009, 2010, 2012 SUSE Linux Product GmbH, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Adrian Schroeter <adrian@suse.de>
# Enhanced by Andreas Jaeger <aj@suse.de>
#
# The script decides if the new build differes from the former one,
# using rpm-check.sh.
# The script is called as part of the build process as:
# /usr/lib/build/same-build-result.sh /.build.oldpackages /usr/src/packages/RPMS /usr/src/packages/SRPMS

CMPSCRIPT=${0%/*}/rpm-check.sh
SCMPSCRIPT=${0%/*}/srpm-check.sh

check_all=1
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

if test `find $NEWDIRS -name '*.rpm' -and ! -name '*.delta.rpm' | wc -l` != `find $OLDDIR -name '*.rpm' -and ! -name '*.delta.rpm' | wc -l`; then
   echo "different number of subpackages"
   find $OLDDIR $NEWDIRS -name '*.rpm' -and ! -name '*.delta.rpm'
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
bash $SCMPSCRIPT "$osrpm" "$nsrpm" || exit 1

# technically we should not all exclude all -32bit but filter for different archs,
# like done with -x86
# but it would be better if this script ran earlier in the build
# sort the rpms so that both lists have the same order
# problem: a package can contain both noarch and arch subpackages, so we have to 
# take care of proper sorting of NEWRPMS, e.g. noarch/x.rpm and x86_64/w.rpm since OLDRPMS 
# has all the packages in a single directory and would sort this as w.rpm, x.rpm.
OLDRPMS=($(find "$OLDDIR" -name \*rpm -a ! -name \*src.rpm  -a ! -name \*.delta.rpm|sort|grep -v -- -32bit-|grep -v -- -64bit-|grep -v -- '-x86-.*\.ia64\.rpm'))
NEWRPMS=($(find $NEWDIRS -name \*rpm -a ! -name \*src.rpm -a ! -name \*.delta.rpm|sort --field-separator=/ --key=7|grep -v -- -32bit-|grep -v -- -64bit-|grep -v -- '-x86-.*\.ia64\.rpm'))

# Get release from first RPM and keep for rpmlint check
# Remember to quote the "." for future regexes
release1=`rpm -qp --nodigest --nosignature --qf "%{RELEASE}" "${OLDRPMS[0]}"|sed -e 's/\./\\./g'`
release2=`rpm -qp --nodigest --nosignature --qf "%{RELEASE}" "${NEWRPMS[0]}"|sed -e 's/\./\\./g'`

SUCCESS=1
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
  bash $CMPSCRIPT "$opac" "$npac" || SUCCESS=0
  if test $SUCCESS -eq 0 -a -z "$check_all"; then
     exit 1
  fi
done

if [ -n "${NEWRPMS[0]}" ]; then
  echo additional new package
  exit 1
fi

# Compare rpmlint.log files
OTHERDIR=/home/abuild/rpmbuild/OTHER

if test -e $OLDDIR/rpmlint.log -a -e $OTHERDIR/rpmlint.log; then
  file1=`mktemp`
  file2=`mktemp`
  echo "comparing $OLDDIR/rpmlint.log and $OTHERDIR/rpmlint.log"
  # Sort the files first since the order of messages is not deterministic
  # Remove release from files
  sort -u $OLDDIR/rpmlint.log|sed -e "s,$release1,@RELEASE@,g" -e "s|/tmp/rpmlint\..*spec|.spec|g" > $file1
  sort -u $OTHERDIR/rpmlint.log|sed -e "s,$release2,@RELEASE@,g" -e "s|/tmp/rpmlint\..*spec|.spec|g"  > $file2
  if ! cmp -s $file1 $file2; then
    echo "rpmlint.log files differ:"
    diff -u $OLDDIR/rpmlint.log $OTHERDIR/rpmlint.log |head -n 20
    SUCCESS=0
  fi
  rm $file1 $file2
elif test -e $OTHERDIR/rpmlint.log; then
  echo "rpmlint.log is new"
  SUCCESS=0
fi

appdatas=`cd $OTHERDIR && find . -name *-appdata.xml`
for xml in $appdatas; do
  # compare appstream data
  if test -e $OLDDIR/$xml -a -e $OTHERDIR/$xml; then
    file1=$OLDDIR/$xml
    file2=$OTHERDIR/$xml
    if ! cmp -s $file1 $file2; then
      echo "$xml files differ:"
      diff -u0 $file1 $file2 |head -n 20
      SUCCESS=0
    fi
  elif test -e $OTHERDIR/$xml; then
    echo "$xml is new"
    SUCCESS=0
  fi
done

if test $SUCCESS -eq 0; then
  exit 1
fi
echo 'compare validated built as identical !'
exit 0
