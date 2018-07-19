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
