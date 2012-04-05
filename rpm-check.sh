#! /bin/bash
#
# Copyright (c) 2009, 2010, 2011 SUSE Linux Product GmbH, Germany.
# Licensed under GPL v2, see COPYING file for details.
#
# Written by Michael Matz and Stephan Coolo
# Enhanced by Andreas Jaeger

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

if test ! -f $oldrpm; then
    echo "can't open $oldrpm"
    exit 1
fi

if test ! -f $newrpm; then
    echo "can't open $newrpm"
    exit 1
fi

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

file1=`mktemp`
file2=`mktemp`

dir=`mktemp -d`
unrpm $oldrpm $dir/old
unrpm $newrpm $dir/new
cd $dir

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
    *.exe.mdb|*.dll.mdb)
       # Just debug information, we can skip them
       echo "$file skipped as debug file."
       return 0
       ;;
    *.a)
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
       #  10-05-2010 14:39
       sed -i -e "s, [0-9][0-9]-[0-9][0-9]-[0-9]\+ [0-9][0-9]:[0-9][0-9] , date ," flist
       # 2012-02-03 07:59
       sed -i -e "s, 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] , date ," flist
       cd ../new
       unjar_l ./$file |sort> flist
       sed -i -e "s, [0-9][0-9]-[0-9][0-9]-[0-9]\+ [0-9][0-9]:[0-9][0-9] , date ,; " flist
       sed -i -e "s, 20[0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9] , date ," flist
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
        perl -e "open fh, '+<', 'old/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
        perl -e "open fh, '+<', 'new/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
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
     *png)
	# Try to remove timestamps, only if convert from ImageMagick is installed
        if [[ $(type -p convert) ]]; then
	  convert old/$file +set date:create +set date:modify old/${file/.png/_n.png}
	  convert old/$file +set date:create +set date:modify new/${file/.png/_n.png}
	  if ! cmp -s old/${file/.png/_n.png} new/${file/.png/_n.png}; then
	      echo "$file differs ($ftype)"
	      hexdump -C old/${file/.png/_n.png} > $file1
	      hexdump -C new/${file/.png/_n.png} > $file2
	      diff -u $file1 $file2 | head -n 20
	      return 1
	  fi
	  return 0
	fi
        ;;
     /usr/share/locale/*/LC_MESSAGES/*.mo|/usr/share/locale-bundle/*/LC_MESSAGES/*.mo)
       for f in old/$file new/$file; do
         sed -i -e "s,POT-Creation-Date: ....-..-.. ..:..+....,POT-Creation-Date: 1970-01-01 00:00+0000," $f
       done
       ;;
     /usr/share/doc/packages/*/*.html|\
     /usr/share/doc/kde/HTML/*/*/*.html|/usr/share/doc/*/html/*.html)
       for f in old/$file new/$file; do
         # texi2html output, e.g. in kvm, indent, qemu
	 sed -i -e "s|^<!-- Created on .*, 20.. by texi2html .\...|<!-- Created on August 7, 2009 by texi2html 1.82|" $f
	 sed -i -e 's|^ *This document was generated by <em>Autobuild</em> on <em>.*, 20..</em> using <a href="http://www.nongnu.org/texi2html/"><em>texi2html .\...</em></a>.$|  This document was generated by <em>Autobuild</em> on <em>August 7, 2009</em> using <a href="http://www.nongnu.org/texi2html/"><em>texi2html 1.82</em></a>.|' $f
	 # doxygen docu, e.g. in libssh and log4c
	 sed -i -e 's|Generated on ... ... [0-9]* [0-9]*:[0-9][0-9]:[0-9][0-9] 20[0-9][0-9] for |Generated on Mon May 10 20:45:00 2010 for |' $f
	 # Generated on Sat Aug 14 2010 16:49:48 for libssh
	 sed -i -e 's|Generated on ... ... [0-9]* 20[0-9][0-9] [0-9]*:[0-9][0-9]:[0-9][0-9] for |Generated on Mon May 10 20:45:00 2010 for |' $f
       done
       ;;
     /usr/share/javadoc/*.html |\
     /usr/share/javadoc/*/*.html|/usr/share/javadoc/*/*/*.html)
       # There are more timestamps in html, so far we handle only some primitive versions.
       for f in old/$file new/$file; do
         # Javadoc:
         sed -i -e "s,^<!-- Generated by javadoc (build [0-9._]*) on ... ... .. ..:..:.. UTC .... -->,^<!-- Generated by javadoc (build 1.6.0_0) on Sun Jul 01 00:00:00 UTC 2000 -->," $f
         sed -i -e 's|^<!-- Generated by javadoc on ... ... .. ..:..:.. UTC ....-->$|<!-- Generated by javadoc on Sun Jul 01 00:00:00 UTC 2000-->|' $f
         sed -i -e 's|<META NAME="date" CONTENT="20..-..-..">|<META NAME="date" CONTENT="1970-01-01">|' $f
         # Gjdoc HtmlDoclet:
	 sed -i -e 's%Generated by Gjdoc HtmlDoclet [0-9,.]*, part of <a href="http://www.gnu.org/software/classpath/cp-tools/" title="" target="_top">GNU Classpath Tools</a>, on .*, 20.. [0-9]*:..:.. \(a\|p\)\.m\. GMT.%Generated by Gjdoc.%' $f
	 sed -i -e 's%<!DOCTYPE html PUBLIC "-//gnu.org///DTD XHTML 1.1 plus Target 1.0//EN"\(.*\)GNU Classpath Tools</a>, on [A-Z][a-z]* [0-9]*, 20?? [0-9]*:??:?? \(a|p\)\.m\. GMT.</p>%<!DOCTYPE html PUBLIC "-//gnu.org///DTD XHTML 1.1 plus Target 1.0//EN"\1GNU Classpath Tools</a>, on January 1, 2009 0:00:00 a.m. GMT.</p>%' $f
	 sed -i -e 's%<!DOCTYPE html PUBLIC "-//gnu.org///DTD\(.*GNU Classpath Tools</a>\), on [a-zA-Z]* [0-9][0-9], 20.. [0-9]*:..:.. \(a\|p\)\.m\. GMT.</p>%<!DOCTYPE html PUBLIC "-//gnu.org///DTD\1,on May 1, 2010 1:11:42 p.m. GMT.</p>%' $f
	 # deprecated-list is randomly ordered, sort it for comparison
	 case $f in
	   */deprecated-list.html)
	     sort -o $f $f 
	     ;;
	 esac
       done
       ;;
     /usr/share/javadoc/gjdoc.properties |\
     /usr/share/javadoc/*/gjdoc.properties)
       for f in old/$file new/$file; do
	 sed -i -e 's|^#[A-Z][a-z]\{2\} [A-Z][a-z]\{2\} [0-9]\{2\} ..:..:.. GMT 20..$|#Fri Jan 01 11:27:36 GMT 2009|' $f
       done
       ;;
     */fonts.scale|*/fonts.dir|*/encodings.dir)
       for f in old/$file new/$file; do
         # sort files before comparing
         sort -o $f $f
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
     /usr/share/man/man*/*|/usr/lib/texmf/doc/man/*/*)
	 # Handles lines like:
	 # .TH debhelper 7 "2010-02-27" "7.4.15" "Debhelper"
	 # .TH DIRMNGR-CLIENT 1 2010-02-27 "Dirmngr 1.0.3" "GNU Privacy Guard"
	 # .TH ccmake 1 "March 06, 2010" "ccmake 2.8.1-rc3"
	 # .TH QEMU-IMG 1 "2010-03-14" " " " "
	 # .TH kdecmake 1 "May 07, 2010" "cmake 2.8.1"
	 # .TH "appender.h" 3 "12 May 2010" "Version 1.2.1" "log4c" \" -*- nroff -*-
	 # .TH "appender.h" 3 "Tue Aug 31 2010" "Version 1.2.1" "log4c" \" -*- nroff -*-
	 # .TH "OFFLINEIMAP" "1" "11 May 2010" "John Goerzen" "OfflineIMAP Manual"
	 # .TH gv 3guile "13 May 2010"
	 #.TH "GIT\-ARCHIMPORT" "1" "09/13/2010" "Git 1\&.7\&.1" "Git Manual"
	 # .TH LDIRECTORD 8 "2010-10-20" "perl v5.12.2" "User Contributed Perl Documentation"

       for f in old/$file new/$file; do
	 sed -i -e 's|.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?\(20[0-9][0-9]-[0-9][0-9]-[0-9][0-9]\|[0-9]* [A-Z][a-z]* 20[0-9][0-9]\)"\? |.TH \1 \2 "2000-01-01" |' $f
	 sed -i -e 's|.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?\([0-1][0-9]/[0-9][0-9]/201[0-9]\)"\? |.TH \1 \2 "2000-01-01" |' $f
	 sed -i -e 's|.TH \(.*\) "\?\(20[0-1][0-9]-[0-9][0-9]-[0-9][0-9]\)"\? |.TH \1  "2000-01-01" |' $f
	 # .TH ccmake 1 "February 05, 2012" "ccmake 2.8.7"
         sed  -i -e 's|^.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?\([A-Z][a-z]* [0-9][0-9], 20[0-9][0-9]\)"\? |.TH \1 \2 "2000-01-01" |' $f
	 # .TH "appender.h" 3 "Tue Aug 31 2010" "Version 1.2.1" "log4c" \" -*- nroff -*-
	 sed -i -e 's|.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?[A-Z][a-z][a-z] [A-Z][a-z][a-z] [0-9]\+ 20[0-9][0-9]"\? |.TH \1 \2 "2000-01-01" |' $f
	 # .TH ARCH "1" "September 2010" "GNU coreutils 8.5" "User Commands"
	 sed -i -e 's|.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?[A-Z][a-z]* 20[0-9][0-9]"\? |.TH \1 \2 "2000-01-01"  |' $f
	 # .TH "GCM-CALIBRATE" "1" "03 February 2012" "" ""
	 sed -i -e 's|.TH "\?\([^ "]*\)"\? "\?\([0-9][a-z]*\)"\? "\?[0-9]* [A-Z][a-z]* 20[0-9][0-9]"\? |.TH \1 \2 "2000-01-01"  |' $f
	 # generated by docbook xml:
	 #.\"      Date: 09/13/2010
         sed -i -e 's|Date: [0-1][0-9]/[0-9][0-9]/201[0-9]|Date: 09/13/2010|' $f
       done
       ;;
     *.elc)
       # emacs lisp files
       for f in old/$file new/$file; do
         sed -i -e 's|Compiled by abuild@.* on ... ... .. ..:..:.. 20..$|compiled by abuild@buildhost on Wed Jul 01 00:00:00 2009|' $f
       done
       ;;
     /var/lib/texmf/web2c/*/*fmt |\
     /var/lib/texmf/web2c/metafont/*.base|\
     /var/lib/texmf/web2c/metapost/*.mem)
       # binary dump of TeX and Metafont formats, we can ignore them for good
       echo "difference in $file ignored."
       return 0
       ;;
     */libtool)
       for f in old/$file new/$file; do
	  sed -i -e 's|^# Libtool was configured on host [a-z0-9]*:$|Libtool was configured on host x42:|' $f
       done
       ;;
     /etc/mail/*cf|/etc/sendmail.cf)
       # from sendmail package
       for f in old/$file new/$file; do
	  # - ##### built by abuild@build33 on Thu May 6 11:21:17 UTC 2010
	  sed -i -e 's|built by abuild@[a-z0-9]* on ... ... [0-9]* [0-9]*:[0-9][0-9]:[0-9][0-9] .* 20[0-9][0-9]|built by abuild@build42 on Thu May 6 11:21:17 UTC 2010|' $f
       done
       ;;
     /usr/share/doc/kde/HTML/*/*/index.cache|/usr/share/doc/kde/HTML/*/*/*/index.cache|\
     /usr/share/gtk-doc/html/*/*.html|/usr/share/gtk-doc/html/*/*.devhelp2)
       # various kde and gtk packages
       for f in old/$file new/$file; do
	  sed -i -e 's%name="id[0-9]*"\([> ]\)%name="id424242"\1%g' $f
	  sed -i -e 's%name="[a-z]*\.id[0-9]*"%name="ftn.id111111"%g' $f
	  sed -i -e 's%\.html#id[0-9]*"\(/\)\?>%.html#id424242"\1>%g' $f
	  sed -i -e 's%href="#\([a-z]*\.\)\?id[0-9]*"\([> ]\)%href="#\1id0000000"\2%g' $f
	  sed -i -e 's%id="\([a-z]*\.\)\?id[0-9]*"\([> ]\)%id="\1id0000000"\2%g' $f
       done
       ;;
    */created.rid)
       # ruby documentation
       # file just contains a timestamp and nothing else, so ignore it
       echo "Ignore $file"
       return 0
       ;;
    */rdoc/files/*.html)
       # ruby documentation
       # <td>Mon Sep 20 19:02:43 +0000 2010</td>
       for f in old/$file new/$file; do
          sed -i -e 's%<td>[A-Z][a-z][a-z] [A-Z][a-z][a-z] [0-9]\+ [0-9]\+:[0-9]\+:[0-9]\+ +0000 201[0-9]</td>%<td>Mon Sep 20 19:02:43 +0000 2010</td>%g' $f
       done
       ;;
    */Linux*Env.Set.sh)
       # LibreOffice files, contains:
       # Generated on: Mon Apr 18 13:19:22 UTC 2011
       for f in old/$file new/$file; do
	 sed -i -e 's%^# Generated on:.*UTC 201[0-9] *$%# Generated on: Sometime%g' $f
       done
       ;;
    /usr/lib/libreoffice/solver/inc/*/deliver.log)
       # LibreOffice log file
      echo "Ignore $file"
      return 0
      ;;
  esac

  ftype=`/usr/bin/file old/$file | cut -d: -f2-`
  case $ftype in
     *PE32\ executable*Mono\/\.Net\ assembly*)
       echo "PE32 Mono/.Net assembly: $file"
       if [ -x /usr/bin/monodis ] ; then
         monodis old/$file 2>/dev/null|sed -e 's/GUID = {.*}/GUID = { 42 }/;'> ${file1}
         monodis new/$file 2>/dev/null|sed -e 's/GUID = {.*}/GUID = { 42 }/;'> ${file2}
         if ! cmp -s ${file1} ${file2}; then
           echo "$file differs ($ftype)"
           diff -u ${file1} ${file2}
           return 1
         fi
       else
         echo "Cannot compare, no monodis installed"
         return 1
       fi
       ;;
    *ELF*executable*|*ELF*LSB\ shared\ object*)
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

# We need /proc mounted for some tests, so check that it's mounted and
# complain if not.
PROC_MOUNTED=0
if [ ! -d /proc/self/ ]; then
  echo "/proc is not mounted"
  mount -orw -n -tproc none /proc
  PROC_MOUNTED=1
fi

ret=0
for file in $files; do
   if ! check_single_file $file; then
       ret=1
       if test -z "$check_all"; then
           break
       fi
   fi
done

if [ "$PROC_MOUNTED" -eq "1" ]; then
  echo "Unmounting proc"
  umount /proc
fi

rm $file1 $file2 $dfile
rm -r $dir
exit $ret
