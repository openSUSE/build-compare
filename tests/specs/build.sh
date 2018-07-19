#!/bin/sh
basedir=$(dirname $0)/../..
export SOURCE_DATE_EPOCH=1532000000
r=../rpms
test -d $r -a $r -nt $0 && exit 0
rm -rf $r
mkdir -p $r

stringtext()
{
    n=$1
    string=$2
    rpmbuild -bb -D '%outfile string.txt' -D "%outcmd echo $string > %outfile" stringtext.spec
    mv ~/rpmbuild/RPMS/x86_64/stringtext-1-0.x86_64.rpm $r/stringtext-1-$n.x86_64.rpm
}

# generate rpms with differing text files
stringtext 0 123456
stringtext 1 123456
stringtext 2 X98765
