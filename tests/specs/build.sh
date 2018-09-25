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
    meta=$3
    outfile=$4
    [ -z "$outfile" ] && outfile=string.txt
    [ -z "$meta" ] && meta="Provides: foo"
    rpmbuild -bb \
        -D "%outfile dir" \
        -D "%outcmd rm -rf dir ; mkdir -p dir ; echo $string > 'dir/$outfile'" \
        -D "%metadata $meta" \
        stringtext.spec || exit 15
    mv ~/rpmbuild/RPMS/x86_64/stringtext-1-0.x86_64.rpm $r/stringtext-1-$n.x86_64.rpm
}

stringtext2()
{
    n=$1
    string=$2
    string2=$3
    rpmbuild -bb -D '%outfile dir' -D "%outcmd rm -rf dir ; mkdir -p dir ; echo -e '$string' > dir/string.txt ; echo -e '$string2' > dir/string2.txt" stringtext.spec
    mv ~/rpmbuild/RPMS/x86_64/stringtext-1-0.x86_64.rpm $r/stringtext-1-$n.x86_64.rpm
}

# generate rpms with differing text files
stringtext 0 123456
stringtext 1 123456
stringtext 2 X98765
stringtext 3 123456 "Provides: bar"
stringtext2 10 123456 789
stringtext2 11 123456 123
stringtext2 12 X98765 123
