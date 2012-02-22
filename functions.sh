#! /bin/bash
#
# Copyright (c) 2009, 2010, 2011, 2012 SUSE Linux Product GmbH, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Coolo
# Enhanced by Andreas Jaeger

# library of functions used by scripts

RPM="rpm -qp --nodigest --nosignature"

check_header() 
{
   $RPM --qf "$QF" "$1"
}

function check_provides()
{

  # provides destroy this because at least the self-provide includes the
  # -buildnumber :-(
  QF="[%{PROVIDENAME} %{PROVIDEFLAGS} %{PROVIDEVERSION}\\n]\\n"
  QF="$QF [%{REQUIRENAME} %{REQUIREFLAGS} %{REQUIREVERSION}\\n]\\n"
  QF="$QF [%{CONFLICTNAME} %{CONFLICTFLAGS} %{CONFLICTVERSION}\\n]\\n"
  QF="$QF [%{OBSOLETENAME} %{OBSOLETEFLAGS} %{OBSOLETEVERSION}\\n]\\n"
  check_header "$1" | sed -e "s,-$2$,-@RELEASE@,"
}

#usage unrpm <file> $dir
# Unpack rpm files in directory $dir
# like /usr/bin/unrpm - just for one file and with no options
function unrpm()
{
    local file
    local dir
    file=$1
    dir=$2
    CPIO_OPTS="--extract --unconditional --preserve-modification-time --make-directories --quiet"
    mkdir -p $dir
    pushd $dir 1>/dev/null
    rpm2cpio $file | cpio ${CPIO_OPTS}
    popd 1>/dev/null
}

# Compare just the rpm meta data of two rpms
# Returns:
# 0 in case of same content
# 1 in case of errors or difference
# 2 in case of differences that need further investigation
# Sets $files with list of files that need further investigation
function cmp_spec ()
{
    QF="%{NAME}"
    
    # don't look at RELEASE, it contains our build number
    QF="$QF %{VERSION} %{EPOCH}\\n"
    QF="$QF %{SUMMARY}\\n%{DESCRIPTION}\\n"
    QF="$QF %{VENDOR} %{DISTRIBUTION} %{DISTURL}"
    QF="$QF %{LICENSE} %{LICENSE}\\n"
    QF="$QF %{GROUP} %{URL} %{EXCLUDEARCH} %{EXCLUDEOS} %{EXCLUSIVEARCH}\\n"
    QF="$QF %{EXCLUSIVEOS} %{RPMVERSION} %{PLATFORM}\\n"
    QF="$QF %{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR} %{PAYLOADFLAGS}\\n"
    
 
    # XXX We also need to check the existence (but not the content (!))
    # of SIGGPG (and perhaps the other SIG*)
    
    # XXX We don't look at triggers
    
    QF="$QF [%{VERIFYSCRIPTPROG} %{VERIFYSCRIPT}]\\n"
    
    # Only the first ChangeLog entry; should be enough
    QF="$QF %{CHANGELOGTIME} %{CHANGELOGNAME} %{CHANGELOGTEXT}\\n"
    
    file1=`mktemp`
    file2=`mktemp`
    
    check_header $oldrpm > $file1
    check_header $newrpm > $file2
    
    # the DISTURL tag can be used as checkin ID
    #echo "$QF"
    if ! diff -au $file1 $file2; then
      rm $file1 $file2
      return 1
    fi
    
    # Remember to quote the . which is in release
    release1=`$RPM --qf "%{RELEASE}" "$oldrpm"|sed -e 's/\./\\./g'`
    release2=`$RPM --qf "%{RELEASE}" "$newrpm"|sed -e 's/\./\\./g'`
    # This might happen with a forced rebuild of factory
    if [ "${release1%.*}" != "${release2%.*}" ] ; then
      echo "release prefix mismatch"
      return 1
    fi
    
    check_provides $oldrpm $release1 > $file1
    check_provides $newrpm $release2 > $file2
    
    if ! diff -au $file1 $file2; then
      rm $file1 $file2
      return 1
    fi

    # scripts, might contain release number
    QF="[%{PREINPROG} %{PREIN}\\n]\\n[%{POSTINPROG} %{POSTIN}\\n]\\n[%{PREUNPROG} %{PREUN}\\n]\\n[%{POSTUNPROG} %{POSTUN}\\n]\\n"
    check_header $oldrpm | sed -e "s,-$release1$,-@RELEASE@," > $file1
    check_header $newrpm | sed -e "s,-$release2$,-@RELEASE@," > $file2

    if ! diff -au $file1 $file2; then
      rm $file1 $file2
      return 1
    fi
    
    # First check the file attributes and later the md5s
    
    # Now the files.  We leave out mtime and size.  For normal files
    # the size will influence the MD5 anyway.  For directories the sizes can
    # differ, depending on which file system the package was built.  To not
    # have to filter out directories we simply ignore all sizes.
    # Also leave out FILEDEVICES, FILEINODES (depends on the build host),
    # FILECOLORS, FILECLASS (normally useful but file output contains mtimes), 
    # FILEDEPENDSX and FILEDEPENDSN. 
    # Also FILELANGS (or?)
    QF="[%{FILENAMES} %{FILEFLAGS} %{FILESTATES} %{FILEMODES:octal} %{FILEUSERNAME} %{FILEGROUPNAME} %{FILERDEVS} %{FILEVERIFYFLAGS} %{FILELINKTOS}\n]\\n"
    # ??? what to do with FILEPROVIDE and FILEREQUIRE?
    
    check_header $oldrpm > $file1
    check_header $newrpm > $file2
    
    if ! diff -au $file1 $file2; then
      rm $file1 $file2
      return 1
    fi
    
    # now the md5sums. if they are different, we check more detailed
    # if there are different filenames, we will already have aborted before
    QF="[%{FILENAMES} %{FILEMD5S}\n]\\n"
    check_header $oldrpm > $file1
    check_header $newrpm > $file2
    
    RES=2
    # done if the same
    if cmp -s $file1 $file2; then
      RES=0
    fi
    
    # Get only files with different MD5sums
    files=`diff -U0 $file1 $file2 | fgrep -v +++ | grep ^+ | cut -b2- | awk '{print $1}'`

    rm $file1 $file2
    return $RES
}
