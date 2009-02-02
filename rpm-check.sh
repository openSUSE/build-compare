#! /bin/bash
# Written by Michael Matz and Stephan Coolo
RPM="rpm -qp --nodigest --nosignature"

if test "$#" != 2; then
   echo "usage: $0 old.rpm new.rpm"
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

filter_disasm()
{
   sed -e 's/^ *[0-9a-f]\+://' -e 's/\$0x[0-9a-f]\+/$something/' -e 's/callq *[0-9a-f]\+/callq /' -e 's/# *[0-9a-f]\+/#  /' -e 's/\(0x\)\?[0-9a-f]\+(/offset(/' -e 's/[0-9a-f]\+ </</' -e 's/^<\(.*\)>:/\1:/' -e 's/<\(.*\)+0x[0-9a-f]\+>/<\1 + ofs>/' 
}

QF="%{NAME}"

# don't look at RELEASE, it contains our build number
QF="$QF %{VERSION} %{EPOCH}\\n"
QF="$QF %{SUMMARY}\\n%{DESCRIPTION}\\n"
# ignored for now
#QF="$QF %{VENDOR} %{DISTRIBUTION}"
QF="$QF %{LICENSE} %{COPYRIGHT}\\n"
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
/usr/bin/unrpm -q $oldrpm
cd ..

mkdir new
cd new
/usr/bin/unrpm -q $newrpm
cd ..

dfile=`mktemp`
ret=0

check_single_file()
{ 
  file=$1
  case $file in
    *.spec)
       sed -i -e "s,Release:.*$release1,Release: @RELEASE@," old/$file
       sed -i -e "s,Release:.*$release2,Release: @RELEASE@," new/$file
       ;;
    *.dll|*.exe)
       # we can't handle it well enough
       echo "mono files unhandled ($file)"
       ret=1
       break;;
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
          check_single_file $fdir/$f
       done
       continue;;
     *.pyc|*.pyo)
        perl -E "open fh, '+<', 'old/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
        perl -E "open fh, '+<', 'new/$file'; seek fh, 3, SEEK_SET; print fh '0000';"
        ;;
     *.bz2)
        bunzip2 old/$file new/$file
        check_single_file ${file/.bz2/}
        continue;;
     *.gz)
        gunzip old/$file new/$file
        check_single_file ${file/.gz/}
        continue;;
  esac

  ftype=`/usr/bin/file old/$file | cut -d: -f2-`
  case $ftype in
    *executable*|*LSB\ shared\ object*)
       objdump -d old/$file | filter_disasm > $file1
       sed -i -e "s,old/,," $file1
       objdump -d new/$file | filter_disasm > $file2
       sed -i -e "s,new/,," $file2
       if ! diff -u $file1 $file2 > $dfile; then
          echo "$file differs in assembler output"
          head -n 2000 $dfile
          ret=1
          break
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
       ret=1
       break
       ;;
     *ASCII*|*text*)
       if ! cmp -s old/$file new/$file; then
         echo "$file differs ($ftype)"
         diff -u old/$file1 new/$file2 | head -n 200
         ret=1
         break
       fi
       ;;
     *)
       if ! cmp -s old/$file new/$file; then
         echo "$file differs ($ftype)"
         hexdump -C old/$file > $file1
         hexdump -C new/$file > $file2
         diff -u $file1 $file2 | head -n 200
         ret=1
         break
       fi
       ;;
  esac
}

for file in $files; do
   check_single_file $file
done

rm $file1 $file2 $dfile
rm -r $dir
exit $ret

