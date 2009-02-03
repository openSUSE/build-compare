#!/bin/bash
#
# Copyright (c) 2009 SUSE Linux Product Gmbh, Germany.  All rights reserved.
#
# Written by Adrian Schroeter <adrian@suse.de>
#
# The script decides if the new build differes from the former one,
# using rpm-check.sh.

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

#OLDRPMS=($(find "$OLDDIR" -name \*src.rpm|sort) $(find "$OLDDIR" -name \*rpm -a ! -name \*src.rpm|sort))
#NEWRPMS=($(find $NEWDIRS -name \*src.rpm|sort) $(find $NEWDIRS -name \*rpm -a ! -name \*src.rpm|sort))
# Exclude src rpms for now:
OLDRPMS=($(find "$OLDDIR" -name \*rpm -a ! -name \*src.rpm|sort))
NEWRPMS=($(find $NEWDIRS -name \*rpm -a ! -name \*src.rpm|sort))

for opac in "$OLDRPMS"; do
  npac=${NEWRPMS[0]}
  NEWRPMS=(${NEWRPMS[@]:1}) # shift
  echo compare "$opac" "$npac"
  bash $CMPSCRIPT "$opac" "$npac" || exit 1
done

echo compare validated built as indentical !
exit 0

