#! /bin/bash
#
# Copyright (c) 2009, 2010, 2011, 2012 SUSE Linux Product GmbH, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Coolo
# Enhanced by Andreas Jaeger

# library of functions used by scripts

RPM="rpm -qp --nodigest --nosignature"

# Name, Version, Release
QF_NAME="%{NAME}"
QF_VER_REL="%{VERSION}-%{RELEASE}"
QF_NAME_VER_REL="%{NAME}-%{VERSION}-%{RELEASE}"

# provides destroy this because at least the self-provide includes the
# -buildnumber :-(
QF_PROVIDES="[%{PROVIDENAME} %{PROVIDEFLAGS} %{PROVIDEVERSION}\\n]\\n"
QF_PROVIDES="${QF_PROVIDES}[%{REQUIRENAME} %{REQUIREFLAGS} %{REQUIREVERSION}\\n]\\n"
QF_PROVIDES="${QF_PROVIDES}[%{CONFLICTNAME} %{CONFLICTFLAGS} %{CONFLICTVERSION}\\n]\\n"
QF_PROVIDES="${QF_PROVIDES}[%{OBSOLETENAME} %{OBSOLETEFLAGS} %{OBSOLETEVERSION}\\n]\\n"

# don't look at RELEASE, it contains our build number
QF_TAGS="%{NAME} %{VERSION} %{EPOCH}\\n"
QF_TAGS="${QF_TAGS}%{SUMMARY}\\n%{DESCRIPTION}\\n"
# the DISTURL tag can be used as checkin ID
QF_TAGS="${QF_TAGS}%{VENDOR} %{DISTRIBUTION} %{DISTURL}\\n"
QF_TAGS="${QF_TAGS}%{LICENSE}\\n"
QF_TAGS="${QF_TAGS}%{GROUP} %{URL} %{EXCLUDEARCH} %{EXCLUDEOS} %{EXCLUSIVEARCH}\\n"
QF_TAGS="${QF_TAGS}%{EXCLUSIVEOS} %{RPMVERSION} %{PLATFORM}\\n"
QF_TAGS="${QF_TAGS}%{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR} %{PAYLOADFLAGS}\\n"

# XXX We also need to check the existence (but not the content (!))
# of SIGGPG (and perhaps the other SIG*)
# XXX We don't look at triggers
QF_TAGS="${QF_TAGS}[%{VERIFYSCRIPTPROG} %{VERIFYSCRIPT}]\\n"
# Only the first ChangeLog entry; should be enough
QF_TAGS="${QF_TAGS}%{CHANGELOGTIME} %{CHANGELOGNAME} %{CHANGELOGTEXT}\\n"

# scripts, might contain release number
QF_SCRIPT="[%{PREINPROG} %{PREIN}\\n]\\n[%{POSTINPROG} %{POSTIN}\\n]\\n[%{PREUNPROG} %{PREUN}\\n]\\n[%{POSTUNPROG} %{POSTUN}\\n]\\n"

# Now the files. We leave out mtime and size.  For normal files
# the size will influence the MD5 anyway.  For directories the sizes can
# differ, depending on which file system the package was built.  To not
# have to filter out directories we simply ignore all sizes.
# Also leave out FILEDEVICES, FILEINODES (depends on the build host),
# FILECOLORS, FILECLASS (normally useful but file output contains mtimes),
# FILEDEPENDSX and FILEDEPENDSN.
# Also FILELANGS (or?)
QF_FILELIST="[%{FILENAMES} %{FILEFLAGS} %{FILESTATES} %{FILEMODES:octal} %{FILEUSERNAME} %{FILEGROUPNAME} %{FILERDEVS} %{FILEVERIFYFLAGS} %{FILELINKTOS}\n]\\n"
# ??? what to do with FILEPROVIDE and FILEREQUIRE?

QF_CHECKSUM="[%{FILENAMES} %{FILEMD5S} %{FILEFLAGS}\n]\\n"

QF_ALL="\n___QF_NAME___\n${QF_NAME}\n___QF_NAME___\n"
QF_ALL="$QF_ALL\n___QF_TAGS___\n${QF_TAGS}\n___QF_TAGS___\n"
QF_ALL="$QF_ALL\n___QF_VER_REL___\n${QF_VER_REL}\n___QF_VER_REL___\n"
QF_ALL="$QF_ALL\n___QF_NAME_VER_REL___\n${QF_NAME_VER_REL}\n___QF_NAME_VER_REL___\n"
QF_ALL="$QF_ALL\n___QF_PROVIDES___\n${QF_PROVIDES}\n___QF_PROVIDES___\n"
QF_ALL="$QF_ALL\n___QF_SCRIPT___\n${QF_SCRIPT}\n___QF_SCRIPT___\n"
QF_ALL="$QF_ALL\n___QF_FILELIST___\n${QF_FILELIST}\n___QF_FILELIST___\n"
QF_ALL="$QF_ALL\n___QF_CHECKSUM___\n${QF_CHECKSUM}\n___QF_CHECKSUM___\n"

check_header()
{
   $RPM --qf "$1" "$2"
}

# Trim version-release string:
# - it is used as direntry below certain paths
# - it is assigned to some variable in scripts, at the end of a line
# - it is used in PROVIDES, at the end of a line
# Trim name-version-release string:
# - it is used in update-scripts which are called by libzypp
function trim_release_old()
{
  sed -e "
  /\(\/boot\|\/lib\/modules\|\/lib\/firmware\|\/usr\/src\|$version_release_old_regex_l\$\|$version_release_old_regex_l)\)/{s,$version_release_old_regex_l,@VERSION@-@RELEASE_LONG@,g;s,$version_release_old_regex_s,@VERSION@-@RELEASE_SHORT@,g}
  s/\(\/var\/adm\/update-scripts\/\)${name_ver_rel_old_regex_l}\([^[:blank:]]\+\)/\1@NAME_VER_REL@\2/g
  s/\(\/var\/adm\/update-messages\/\)${name_ver_rel_old_regex_l}\([^[:blank:]]\+\)/\1@NAME_VER_REL@\2/g
  "
}
function trim_release_new()
{
  sed -e "
  /\(\/boot\|\/lib\/modules\|\/lib\/firmware\|\/usr\/src\|$version_release_new_regex_l\$\|$version_release_new_regex_l)\)/{s,$version_release_new_regex_l,@VERSION@-@RELEASE_LONG@,g;s,$version_release_new_regex_s,@VERSION@-@RELEASE_SHORT@,g}
  s/\(\/var\/adm\/update-scripts\/\)${name_ver_rel_new_regex_l}\([^[:blank:]]\+\)/\1@NAME_VER_REL@\2/g
  s/\(\/var\/adm\/update-messages\/\)${name_ver_rel_new_regex_l}\([^[:blank:]]\+\)/\1@NAME_VER_REL@\2/g
  "
}
# Get single directory or filename with long or short release string
function grep_release_old()
{
  grep -E "(/boot|/lib/modules|/lib/firmware|/usr/src|/var/adm/update-scripts)/[^/]*(${version_release_old_regex_l}(\$|[^/]+\$)|${version_release_old_regex_s}(\$|[^/]+\$))"
}
function grep_release_new()
{
  grep -E "(/boot|/lib/modules|/lib/firmware|/usr/src|/var/adm/update-scripts)/[^/]*(${version_release_new_regex_l}(\$|[^/]+\$)|${version_release_new_regex_s}(\$|[^/]+\$))"
}

#usage unpackage <file> $dir
# Unpack files in directory $dir
# like /usr/bin/unpackage - just for one file and with no options
function unpackage()
{
    local file
    local dir
    file=$1
    dir=$2
    mkdir -p $dir
    pushd $dir 1>/dev/null
    case $file in
        *.bz2)
            bzip2 -d $file
            ;;
        *.gz)
            gzip -d $file
            ;;
        *.xz)
            xz -d $file
            ;;
        *.tar|*.tar.bz2|*.tar.gz|*.tgz|*.tbz2)
            tar xf $file
            ;;
        *.rpm)
            CPIO_OPTS="--extract --unconditional --preserve-modification-time --make-directories --quiet"
            rpm2cpio $file | cpio ${CPIO_OPTS}
            ;;
        *.ipk|*.deb)
            ar x $file
            tar xf control.tar.gz
            rm control.tar.gz
            tar xf data.tar.[xg]z
            rm data.tar.[xg]z
            ;;
    esac
    popd 1>/dev/null
}

# Run diff command on the files
# $1: printed info
# $2: file1
# $3: file2
# $4, $5: spec_old and spec_new, for cleanup.
function comp_file()
{
    echo "comparing $1"
    if ! diff -au $2 $3; then
      if test -z "$check_all"; then
        rm $2 $3 $4 $5
        return 1
      fi
    fi
    return 0
}

# Get var's value from specfile.
# $1: var name
# $2: specfile
function get_value()
{
    sed -n -e "/^___${1}___/,/^___${1}___/p" $2 | sed -e "/^___${1}___/d"
}

# Set version_release_old_regex_s, version_release_old_regex_l and
# name_ver_rel_old_regex_l, also the new ones.
function set_regex() {
    # Remember to quote the . which is in release
    # Short version without B_CNT
    version_release_old_regex_s=${version_release_old%.*}
    version_release_old_regex_s=${version_release_old_regex_s//./\\.}
    version_release_new_regex_s=${version_release_new%.*}
    version_release_new_regex_s=${version_release_new_regex_s//./\\.}
    # Long version with B_CNT
    version_release_old_regex_l=${version_release_old//./\\.}
    version_release_new_regex_l=${version_release_new//./\\.}
    name_ver_rel_old_regex_l=${name_ver_rel_old//./\\.}
    name_ver_rel_new_regex_l=${name_ver_rel_new//./\\.}
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
    local oldrpm=$2
    local newrpm=$3

    file1=`mktemp`
    file2=`mktemp`
    spec_old=`mktemp`
    spec_new=`mktemp`

    check_header "$QF_ALL" $oldrpm > $spec_old
    check_header "$QF_ALL" $newrpm > $spec_new

    name_new="$(get_value QF_NAME $spec_new)"
    version_release_new="$(get_value QF_VER_REL $spec_new)"
    name_ver_rel_new="$(get_value QF_NAME_VER_REL $spec_new)"

    version_release_old="$(get_value QF_VER_REL $spec_old)"
    name_ver_rel_old="$(get_value QF_NAME_VER_REL $spec_old)"

    set_regex

    # Check the whole spec file at first, return 0 immediately if the
    # are the same.
    cat $spec_old | trim_release_old > $file1
    cat $spec_new | trim_release_new > $file2
    echo "comparing the rpm tags of $name_new"
    if diff -au $file1 $file2; then
      if test -z "$check_all"; then
        rm $file1 $file2 $spec_old $spec_new
        return 0
      fi
    fi

    get_value QF_TAGS $spec_old > $file1
    get_value QF_TAGS $spec_new > $file2
    comp_file rpmtags $file1 $file2 $spec_old $spec_new || return 1

    # This might happen when?!
    echo "comparing RELEASE"
    if [ "${version_release_old%.*}" != "${version_release_new%.*}" ] ; then
      case $name_new in
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

    get_value QF_PROVIDES $spec_old | trim_release_old | sort > $file1
    get_value QF_PROVIDES $spec_new | trim_release_new | sort > $file2
    comp_file PROVIDES $file1 $file2 $spec_old $spec_new || return 1

    get_value QF_SCRIPT $spec_old | trim_release_old > $file1
    get_value QF_SCRIPT $spec_new | trim_release_new > $file2
    comp_file scripts $file1 $file2 $spec_old $spec_new || return 1

    # First check the file attributes and later the md5s
    get_value QF_FILELIST $spec_old | trim_release_old > $file1
    get_value QF_FILELIST $spec_new | trim_release_new > $file2
    comp_file filelist $file1 $file2 $spec_old $spec_new || return 1

    # now the md5sums. if they are different, we check more detailed
    # if there are different filenames, we will already have aborted before
    # file flag 64 means "ghost", filter those out.
    get_value QF_CHECKSUM $spec_old | grep -v " 64$" | trim_release_old > $file1
    get_value QF_CHECKSUM $spec_new | grep -v " 64$" | trim_release_new > $file2
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

function adjust_controlfile() {
    version_release_old="`sed -ne 's/^Version: \(.*\)/\1/p' $1/control`"
    name_ver_rel_old="`sed -n -e 's/^Package: \(.*\)/\1/p' $1/control`-`sed -n -e 's/^Version: \(.*\)/\1/p' $1/control`"
    version_release_new="`sed -ne 's/^Version: \(.*\)/\1/p' $2/control`"
    name_ver_rel_new="`sed -n -e 's/^Package: \(.*\)/\1/p' $2/control`-`sed -n -e 's/^Version: \(.*\)/\1/p' $2/control`"
    set_regex
    cat $1/control | trim_release_old > $1/control.fixed
    mv $1/control.fixed $1/control
    cat $2/control | trim_release_new > $2/control.fixed
    mv $2/control.fixed $2/control
}


# vim: tw=666 ts=2 shiftwidth=2 et
