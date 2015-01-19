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

# Trim version-release string:
# - it is used as direntry below certain paths
# - it is assigned to some variable in scripts, at the end of a line
# - it is used in PROVIDES, at the end of a line
function trim_release_old()
{
  sed -e "/\(\/boot\|\/lib\/modules\|\/lib\/firmware\|\/usr\/src\|$version_release_old_regex_l\$\)/{s,$version_release_old_regex_l,@VERSION@-@RELEASE_LONG@,g;s,$version_release_old_regex_s,@VERSION@-@RELEASE_SHORT@,g}"
}
function trim_release_new()
{
  sed -e "/\(\/boot\|\/lib\/modules\|\/lib\/firmware\|\/usr\/src\|$version_release_new_regex_l\$\)/{s,$version_release_new_regex_l,@VERSION@-@RELEASE_LONG@,g;s,$version_release_new_regex_s,@VERSION@-@RELEASE_SHORT@,g}"
}
# Get single directory or filename with long or short release string
function grep_release_old()
{
  grep -E "(/boot|/lib/modules|/lib/firmware|/usr/src)/[^/]+(${version_release_old_regex_l}(\$|[^/]+\$)|${version_release_old_regex_s}(\$|[^/]+\$))"
}
function grep_release_new()
{
  grep -E "(/boot|/lib/modules|/lib/firmware|/usr/src)/[^/]+(${version_release_new_regex_l}(\$|[^/]+\$)|${version_release_new_regex_s}(\$|[^/]+\$))"
}

function check_provides()
{
  local pkg=$1
  # provides destroy this because at least the self-provide includes the
  # -buildnumber :-(
  QF="[%{PROVIDENAME} %{PROVIDEFLAGS} %{PROVIDEVERSION}\\n]\\n"
  QF="$QF [%{REQUIRENAME} %{REQUIREFLAGS} %{REQUIREVERSION}\\n]\\n"
  QF="$QF [%{CONFLICTNAME} %{CONFLICTFLAGS} %{CONFLICTVERSION}\\n]\\n"
  QF="$QF [%{OBSOLETENAME} %{OBSOLETEFLAGS} %{OBSOLETEVERSION}\\n]\\n"
  check_header "$pkg"
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
    local RES
    local file1 file2
    local f
    local sh=$1

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
    echo "comparing rpmtags"
    if ! diff -au $file1 $file2; then
      if test -z "$check_all"; then
        rm $file1 $file2
        return 1
      fi
    fi
    
    # Remember to quote the . which is in release
    version_release_old=$($RPM --qf "%{VERSION}-%{RELEASE}" "$oldrpm")
    version_release_new=$($RPM --qf "%{VERSION}-%{RELEASE}" "$newrpm")
    # Short version without B_CNT
    version_release_old_regex_s=${version_release_old%.*}
    version_release_old_regex_s=${version_release_old_regex_s//./\\.}
    version_release_new_regex_s=${version_release_new%.*}
    version_release_new_regex_s=${version_release_new_regex_s//./\\.}
    # Long version with B_CNT
    version_release_old_regex_l=${version_release_old//./\\.}
    version_release_new_regex_l=${version_release_new//./\\.}
    # This might happen when?!
    echo "comparing RELEASE"
    if [ "${version_release_old%.*}" != "${version_release_new%.*}" ] ; then
      case $($RPM --qf '%{NAME}' "$newrpm") in
        kernel-*)
          # Make sure all kernel packages have the same %RELEASE
          echo "release prefix mismatch"
          if test -z "$check_all"; then
            return 1
          fi
          ;;
        # Every other package is allowed to have a different RELEASE
        *) ;;
      esac
    fi
    
    check_provides $oldrpm | trim_release_old | sort > $file1
    check_provides $newrpm | trim_release_new | sort > $file2
    
    echo "comparing PROVIDES"
    if ! diff -au $file1 $file2; then
      if test -z "$check_all"; then
        rm $file1 $file2
        return 1
      fi
    fi

    # scripts, might contain release number
    QF="[%{PREINPROG} %{PREIN}\\n]\\n[%{POSTINPROG} %{POSTIN}\\n]\\n[%{PREUNPROG} %{PREUN}\\n]\\n[%{POSTUNPROG} %{POSTUN}\\n]\\n"
    check_header $oldrpm | trim_release_old > $file1
    check_header $newrpm | trim_release_new > $file2

    echo "comparing scripts"
    if ! diff -au $file1 $file2; then
      if test -z "$check_all"; then
        rm $file1 $file2
        return 1
      fi
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

    check_header $oldrpm | trim_release_old > $file1
    check_header $newrpm | trim_release_new > $file2
    
    echo "comparing filelist"
    if ! diff -au $file1 $file2; then
      if test -z "$check_all"; then
        rm $file1 $file2
        return 1
      fi
    fi
    
    # now the md5sums. if they are different, we check more detailed
    # if there are different filenames, we will already have aborted before
    # file flag 64 means "ghost", filter those out.
    QF="[%{FILENAMES} %{FILEMD5S} %{FILEFLAGS}\n]\\n"
    check_header $oldrpm |grep -v " 64$"| trim_release_old > $file1
    check_header $newrpm |grep -v " 64$"| trim_release_new > $file2
    
    RES=2
    # done if the same
    echo "comparing file checksum"
    if cmp -s $file1 $file2; then
      RES=0
    fi
    
    # Get only files with different MD5sums
    files=`diff -U0 $file1 $file2 | fgrep -v +++ | grep ^+ | cut -b2- | awk '{print $1}'`

    if test -f "$sh"; then
      echo "creating rename script"
      # Create a temporary helper script to rename files/dirs with release in it
      for f in `$RPM --qf '[%{FILENAMES} %{FILEFLAGS}\n]\n' "$oldrpm" | grep_release_old | grep -vw 64$ | awk '{ print $1}'`
      do
        echo mv -v \"old/${f}\" \"old/`echo ${f} | trim_release_old`\"
      done >> "${sh}"
      #
      for f in `$RPM --qf '[%{FILENAMES} %{FILEFLAGS}\n]\n' "$newrpm" | grep_release_new | grep -vw 64$ | awk '{ print $1}'`
      do
        echo mv -v \"new/${f}\" \"new/`echo ${f} | trim_release_new`\"
      done >> "${sh}"
    fi
    #
    rm $file1 $file2
    return $RES
}
