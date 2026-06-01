#!/usr/bin/env roundup

describe "roundup(1) testing of pkg-diff with .deb files"

basedir=$(dirname $BASH_SOURCE)/..
p=$basedir/pkg-diff.sh
o=$basedir/same-build-result.sh

# one-time prep: build the test debs
( cd specs && ./build-debs.sh ) || exit 11

debs=$(dirname $BASH_SOURCE)/debs

it_treats_byte_equivalent_debs_as_identical()
{
    $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-1_1.0-1_all.deb
}

it_detects_payload_changes()
{
    ! $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-2_1.0-1_all.deb \
        || return 1
    $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-2_1.0-1_all.deb \
        | grep '^+hello changed$'
}

it_detects_control_field_changes()
{
    ! $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-3_1.0-1_all.deb \
        || return 1
    $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-3_1.0-1_all.deb \
        | grep '^+Depends: bar$'
}

it_treats_version_only_rebuild_as_identical()
{
    # Mirror the rpm "same build result" semantic: identical content
    # with bumped version-release is still an unchanged build because
    # the source-rpm / source-dsc layer is checked separately.
    $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-4_1.0-2_all.deb
}

it_detects_control_script_changes()
{
    ! $p $debs/hello-1-0_1.0-1_all.deb $debs/hello-1-5_1.0-1_all.deb \
        || return 1
}

it_orchestrator_treats_identical_sets_as_unchanged()
{
    $o $debs/old-set $debs/new-set-identical
}

it_orchestrator_reports_missing_subpackage()
{
    ! $o $debs/old-set $debs/new-set-missing 2>&1 || return 1
    $o $debs/old-set $debs/new-set-missing 2>&1 \
        | grep 'different number of subpackages'
}

it_orchestrator_reports_payload_diff()
{
    ! $o $debs/old-set $debs/new-set-payload-changed 2>&1 || return 1
    $o $debs/old-set $debs/new-set-payload-changed 2>&1 \
        | grep 'binaries_differ'
}

it_orchestrator_pairs_across_version_bumps()
{
    # Same content, different filenames (version bump only).  The
    # orchestrator must pair by (name, arch), not by full basename, so
    # this set should still come out identical.
    $o $debs/old-set $debs/new-set-version-bump
}

it_normalises_debian_changelog_version_header()
{
    # Reproduces the real-world scenario where a snapshot rebuild only
    # bumps the version in the top changelog stanza.  pkg-diff.sh must
    # treat the two debs as identical.
    $o $debs/changelog-old $debs/changelog-new
}

it_normalises_symbols_file_version()
{
    # Reproduces the real-world scenario where the package version is
    # embedded inside DEBIAN/symbols (e.g. PRIVATE symbol versions).
    # cmp_deb_meta must run trim_release on the symbols file before
    # declaring a metadata difference.
    $o $debs/symbols-old $debs/symbols-new
}
