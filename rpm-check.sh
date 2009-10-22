#! /bin/bash
#
# Copyright (c) 2009 SUSE Linux Product Gmbh, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Coolo
# Enhanced by Andreas Jaeger

RPM="rpm -qp --nodigest --nosignature"

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

oldrpm=`readlink -f $1`
newrpm=`readlink -f $2`

if test ! -f $oldrpm; then
    echo "can't open $oldrpm"
    exit 1
fi

if test ! -f $newrpm; then
    echo "can't open $newrpm"
    exit 1
fi

#usage unrpm <file>
# Unpack rpm files in current directory
# like /usr/bin/unrpm - just for one file and with no options
function unrpm()
{
    local file
    file=$1
    CPIO_OPTS="--extract --unconditional --preserve-modification-time --make-directories --quiet"

    rpm2cpio $file | cpio ${CPIO_OPTS}
}

#usage unjar <file>
function unjar()
{
    local file
    file=$1

    if [[ $(type -p fastjar) ]]; then
        UNJAR=fastjar
    elif [[ $(type -p jar) ]]; then
        UNJAR=jar
    elif [[ $(type -p unzip) ]]; then
        UNJAR=unzip
    else
        echo "ERROR: jar, fastjar, or unzip is not installed (trying file $file)"
        exit 1
    fi

    case $UNJAR in
        jar|fastjar)
        # echo jar -xf $file
        ${UNJAR} -xf $file
        ;;
        unzip)
        unzip -oqq $file
        ;;
    esac
}

# list files in directory
#usage unjar_l <file>
function unjar_l()
{
    local file
    file=$1

    if [[ $(type -p fastjar) ]]; then
        UNJAR=fastjar
    elif [[ $(type -p jar) ]]; then
        UNJAR=jar
    elif [[ $(type -p unzip) ]]; then
        UNJAR=unzip
    else
        echo "ERROR: jar, fastjar, or unzip is not installed (trying file $file)"
        exit 1
    fi

    case $UNJAR in
        jar|fastjar)
        ${UNJAR} -tf $file
        ;;
        unzip)
        unzip -l $file
        ;;
    esac
}

filter_disasm()
{
   sed -e 's/^ *[0-9a-f]\+://' -e 's/\$0x[0-9a-f]\+/$something/' -e 's/callq *[0-9a-f]\+/callq /' -e 's/# *[0-9a-f]\+/#  /' -e 's/\(0x\)\?[0-9a-f]\+(/offset(/' -e 's/[0-9a-f]\+ </</' -e 's/^<\(.*\)>:/\1:/' -e 's/<\(.*\)+0x[0-9a-f]\+>/<\1 + ofs>/' 
}

QF="%{NAME}"

# don't look at RELEASE, it contains our build number
QF="$QF %{VERSION} %{EPOCH}\\n"
QF="$QF %{SUMMARY}\\n%{DESCRIPTION}\\n"
QF="$QF %{VENDOR} %{DISTRIBUTION} %{DISTURL}"
QF="$QF %{LICENSE} %{LICENSE}\\n"
QF="$QF %{GROUP} %{URL} %{EXCLUDEARCH} %{EXCLUDEOS} %{EXCLUSIVEARCH}\\n"
QF="$QF %{EXCLUSIVEOS} %{RPMVERSION} %{PLATFORM}\\n"
QF="$QF %{PAYLOADFORMAT} %{PAYLOADCOMPRESSOR} %{PAYLOADFLAGS}\\n"

QF="$QF [%{PREINPROG} %{PREIN}\\n]\\n[%{POSTINPROG} %{POSTIN}\\n]\\n[%{PREUNPROG} %{PREUN}\\n]\\n[%{POSTUNPROG} %{POSTUN}\\n]\\n"

# XXX We also need to check the existence (but not the content (!))
# of SIGGPG (and perhaps the other SIG*)

# XXX We don't look at triggers

QF="$QF [%{VERIFYSCRIPTPROG} %{VERIFYSCRIPT}]\\n"

# Only the first ChangeLog entry; should be enough
QF="$QF %{CHANGELOGTIME} %{CHANGELOGNAME} %{CHANGELOGTEXT}\\n"

file1=`mktemp`
file2=`mktemp`

check_header() 
{
   $RPM --qf "$QF" "$1"
}

check_header $oldrpm > $file1
check_header $newrpm > $file2

# the DISTURL tag can be used as checkin ID
#echo "$QF"
if ! diff -au $file1 $file2; then
  rm $file1 $file2
  exit 1
fi

release1=`$RPM --qf "%{RELEASE}" "$oldrpm"`
release2=`$RPM --qf "%{RELEASE}" "$newrpm"`

check_provides()
{

  # provides destroy this because at least the self-provide includes the
  # -buildnumber :-(
  QF="[%{PROVIDENAME} %{PROVIDEFLAGS} %{PROVIDEVERSION}\\n]\\n"
  QF="$QF [%{REQUIRENAME} %{REQUIREFLAGS} %{REQUIREVERSION}\\n]\\n"
  QF="$QF [%{CONFLICTNAME} %{CONFLICTFLAGS} %{CONFLICTVERSION}\\n]\\n"
  QF="$QF [%{OBSOLETENAME} %{OBSOLETEFLAGS} %{OBSOLETEVERSION}\\n]\\n"
  check_header "$1" | sed -e "s,-$2,-@RELEASE@,"
}

check_provides $oldrpm $release1 > $file1
check_provides $newrpm $release2 > $file2

if ! diff -au $file1 $file2; then
  rm $file1 $file2
  exit 1
fi

# First check the file attributes and later the md5s

# Now the files.  We leave out mtime and size.  For normal files
# the size will influence the MD5 anyway.  For directories the sizes can
# differ, depending on which file system the package was built.  To not
# have to filter out directories we simply ignore all sizes.
# Also leave out FILEDEVICES, FILEINODES (depends on the build host),
# FILECOLORS, FILECLASS (???), FILEDEPENDSX and FILEDEPENDSN.
# Also FILELANGS (or?)
QF="[%{FILENAMES} %{FILEFLAGS} %{FILESTATES} %{FILEMODES:octal} %{FILEUSERNAME} %{FILEGROUPNAME} %{FILERDEVS} %{FILEVERIFYFLAGS} %{FILELINKTOS}\n]\\n"
# ??? what to do with FILEPROVIDE and FILEREQUIRE?

check_header $oldrpm > $file1
check_header $newrpm > $file2

if ! diff -au $file1 $file2; then
  rm $file1 $file2
  exit 1
fi

# now the md5sums. if they are different, we check more detailed
# if there are different filenames, we will already have aborted before
QF="[%{FILENAMES} %{FILEMD5S}\n]\\n"
check_header $oldrpm > $file1
check_header $newrpm > $file2

# done if the same
if cmp -s $file1 $file2; then
  rm $file1 $file2
  exit 0
fi

files=`diff -U0 $file1 $file2 | fgrep -v +++ | grep ^+ | cut -b2- | awk '{print $1}'`

dir=`mktemp -d`
cd $dir
mkdir old
cd old
unrpm $oldrpm
cd ..

mkdir new
cd new
unrpm $newrpm
cd ..

dfile=`mktemp`

diff_two_files()
{
  if ! cmp -s old/$file new/$file; then
     echo "$file differs ($ftype)"
     hexdump -C old/$file > $file1
     hexdump -C new/$file > $file2
     diff -u $file1 $file2 | head -n 200
     return 1
  fi
  return 0
}

check_single_file()
{ 
  local file=$1
  case $file in
    *.spec)
       sed -i -e "s,Release:.*$release1,Release: @RELEASE@," old/$file
       sed -i -e "s,Release:.*$release2,Release: @RELEASE@," new/$file
       ;;
    *.dll|*.exe)
       # we can't handle it well enough
       if ! cmp -s old/$file new/$file; then
         echo "mono $file differs"
         return 1
       fi
       return 0
       ;;
    *.a)
       echo "$file is .a"
       flist=`ar t new/$file`
       pwd=$PWD
       fdir=`dirname $file`
       cd old/$fdir
       ar x `basename $file`
       cd $pwd/new/$fdir
       ar x `basename $file`
       cd $pwd
       for f in $flist; do
          if ! check_single_file $fdir/$f; then
             return 1
          fi
       done
       return 0
       ;;
    *.tar|*.tar.bz2|*.tar.gz|*.tgz|*.tbz2)
       flist=`tar tf new/$file`
       pwd=$PWD
       fdir=`dirname $file`
       cd old/$fdir
       tar xf `basename $file`
       cd $pwd/new/$fdir
       tar xf `basename $file`
       cd $pwd
       local ret=0
       for f in $flist; do
         if ! check_single_file $fdir/$f; then
           ret=1
           if test -z "$check_all"; then
             break
           fi
         fi
       done
       return $ret
       ;;
    *.zip|*.jar)
       cd old
       unjar_l ./$file |sort > flist
       sed -i -e "s, [0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] , date ," flist
       cd ../new
       unjar_l ./$file |sort> flist
       sed -i -e "s, [0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] , date ,; " flist
       cd ..
       if ! cmp -s old/flist new/flist; then
          echo "$file has different file list"
          diff -u old/flist new/flist
          return 1
       fi
       flist=`grep date new/flist | sed -e 's,.* date ,,'`
       pwd=$PWD
       fdir=`dirname $file`
       cd old/$fdir
       unjar `basename $file`
       cd $pwd/new/$fdir
       unjar `basename $file`
       cd $pwd
       local ret=0
       for f in $flist; do
         if test -f new/$fdir/$f && ! check_single_file $fdir/$f; then
           ret=1
           if test -z "$check_all"; then
             break
           fi
         fi
       done
       return $ret;;
     *.pyc|*.pyo)
        perl -E "open fh, '+<', 'old/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
        perl -E "open fh, '+<', 'new/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
        ;;
     *.bz2)
        bunzip2 -c old/$file > old/${file/.bz2/}
        bunzip2 -c new/$file > new/${file/.bz2/}
        check_single_file ${file/.bz2/}
        return $?
        ;;
     *.gz)
        gunzip -c old/$file > old/${file/.gz/}
        gunzip -c new/$file > new/${file/.gz/}
        check_single_file ${file/.gz/}
        return $?
        ;;
     /usr/share/locale/*/LC_MESSAGES/*.mo|/usr/share/locale-bundle/*/LC_MESSAGES/*.mo)
       for f in old/$file new/$file; do
         sed -i -e "s,POT-Creation-Date: ....-..-.. ..:..+....,POT-Creation-Date: 1970-01-01 00:00+0000," $f
       done
       ;;
     /usr/share/doc/packages/*/*.html)
       # texi2html output, e.g. in kvm, indent
       for f in old/$file new/$file; do
	 sed -i -e "s|^<!-- Created on .*, 20.. by texi2html .\...$|<!-- Created on August 7, 2009 by texi2html 1.82|" $f
	 sed -i -e 's|^ This document was generated by <em>Autobuild</em> on <em>.*, 20..</em> using <a href="http://www.nongnu.org/texi2html/"><em>texi2html .\...</em></a>.$|  This document was generated by <em>Autobuild</em> on <em>August 7, 2009</em> using <a href="http://www.nongnu.org/texi2html/"><em>texi2html 1.82</em></a>.|' $f
       done
       ;;
     /usr/share/javadoc/*/*.html|/usr/share/javadoc/*/*/*.html)
       # There are more timestamps in html, so far we handle only some primitive versions.
       for f in old/$file new/$file; do
         # Javadoc:
         sed -i -e "s,^<!-- Generated by javadoc (build .......) on ... ... .. ..:..:.. UTC .... -->,^<!-- Generated by javadoc (build 1.6.0_0) on Sun Jul 01 00:00:00 UTC 2000 -->," $f
         sed -i -e 's|^<!-- Generated by javadoc on ... ... .. ..:..:.. UTC ....-->$|<!-- Generated by javadoc on Sun Jul 01 00:00:00 UTC 2000-->|' $f
         sed -i -e 's|<META NAME="date" CONTENT="20..-..-..">|<META NAME="date" CONTENT="1970-01-01">|' $f
         # Gjdoc HtmlDoclet:
         sed -i -e 's|Generated by Gjdoc HtmlDoclet 0...., part of <a href="http://www.gnu.org/software/classpath/cp-tools/" title="" target="_top">GNU Classpath Tools</a>, on .*, 20.. ..:..:.. ..m. GMT.|Generated by Gjdoc.|' $f
       done
       ;;
     */fonts.scale|*/fonts.dir|*/encodings.dir)
       for f in old/$file new/$file; do
         # sort files before comparing
         sort $f > $f.tmp
         mv $f.tmp $f
       done
       ;;
     /var/adm/perl-modules/*)
       for f in old/$file new/$file; do
         sed -i -e 's|^=head2 ... ... .. ..:..:.. ....: C<Module>|=head2 Wed Jul  1 00:00:00 2009: C<Module>|' $f
       done
       ;;
     /usr/share/man/man3/*3pm)
       for f in old/$file new/$file; do
         sed -i -e 's| 3 "20..-..-.." "perl v5....." "User Contributed Perl Documentation"$| 3 "2009-01-01" "perl v5.10.0" "User Contributed Perl Documentation"|' $f
       done
       ;;
     *.elc)
       # emacs lisp files
       for f in old/$file new/$file; do
         sed -i -e 's|Compiled by abuild@.* on ... ... .. ..:..:.. 20..$|compiled by abuild@buildhost on Wed Jul 01 00:00:00 2009|' $f
       done
       ;;
     /var/lib/texmf/web2c/*/*fmt)
       # same of these are gzip compressed
       for f in old/$file new/$file; do
         fftype=`/usr/bin/file $f | cut -d: -f2-`
         case $fftype in 
         *gzip\ compressed\ data*)
            gunzip -cd $f > $f.tmp
            mv $f.tmp $f
            ;;
         *)
            ;;
         esac
         # date is of variable length, e.g. 2009.7.21
         sed -i -e 's|(format=[a-z]*tex 20..\.[0-9]*\.[0-9]*)|(format=luatex 2009.1.1)|' $f
       done
       ;;
  esac

  ftype=`/usr/bin/file old/$file | cut -d: -f2-`
  case $ftype in
    *executable*|*LSB\ shared\ object*)
       objdump -d --no-show-raw-insn old/$file | filter_disasm > $file1
       if ! test -s $file1; then
         # objdump has no idea how to handle it
         if ! diff_two_files; then
           ret=1
           break
         fi
       fi       
       sed -i -e "s,old/,," $file1
       objdump -d --no-show-raw-insn new/$file | filter_disasm > $file2
       sed -i -e "s,new/,," $file2
       if ! diff -u $file1 $file2 > $dfile; then
          echo "$file differs in assembler output"
          head -n 200 $dfile
          return 1
       fi
       objdump -s old/$file > $file1
       sed -i -e "s,old/,," $file1
       objdump -s new/$file > $file2
       sed -i -e "s,new/,," $file2
       if ! diff -u $file1 $file2 > $dfile; then
          echo "$file differs in ELF sections"
          head -n 200 $dfile
       else
          echo "WARNING: no idea about $file"
       fi
       return 1
       ;;
     *ASCII*|*text*)
       if ! cmp -s old/$file new/$file; then
         echo "$file differs ($ftype)"
         diff -u old/$file new/$file | head -n 200
         return 1
       fi
       ;;
     *directory)
       # tar might package directories - ignore them here
       return 0
       ;;
     *)
       if ! diff_two_files; then
           return 1
       fi
       ;;
  esac
  return 0
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

rm $file1 $file2 $dfile
rm -r $dir
exit $ret

