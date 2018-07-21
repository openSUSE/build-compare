#!/usr/bin/env roundup

describe "roundup(1) testing of pkg-diff"

basedir=$(dirname $BASH_SOURCE)/..
p=$basedir/pkg-diff.sh

# one-time prep
( cd specs && ./build.sh ) || exit 11

it_finds_text_diff()
{
    $p rpms/stringtext-1-[01].*.rpm
    ! $p rpms/stringtext-1-[02].*.rpm
}

it_prints_md5_diff()
{
    $p rpms/stringtext-1-[02].*.rpm | grep '^-/usr/share/doc/packages/stringtext/string.txt f447b20a7fcbf53a5d5be013ea0b1' #= echo 123456|md5sum
}

it_prints_text_diff()
{
    $p rpms/stringtext-1-[02].*.rpm | grep '^-123456$'
    $p rpms/stringtext-1-[02].*.rpm | grep '^+++ new//usr/share/doc/packages/stringtext/string.txt'
}

it_finds_diff_even_with_identical_files()
{
    ! $p -a rpms/stringtext-1-1[01].*.rpm
    ! $p -a rpms/stringtext-1-1[02].*.rpm
    ! $p -a rpms/stringtext-1-1[12].*.rpm
}

it_reports_missing_files()
{
    ! $p -a rpms/stringtext-1-{2,12}.*.rpm
    $p -a rpms/stringtext-1-{2,12}.*.rpm | grep 'string2.txt differs'
}
