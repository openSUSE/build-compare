#!/bin/sh
# Build the .deb fixtures used by pkg-diff-deb-test.sh.
#
# Naming scheme:
#   hello-<n>_<version>_all.deb
# where <n> is a unique fixture index used to disambiguate otherwise
# identically-named packages with different content/metadata.
#
# We also produce three orchestrator fixture directories:
#   old-set/                 - reference set (foo + bar)
#   new-set-identical/       - byte-equivalent rebuild of old-set
#   new-set-missing/         - old-set minus bar
#   new-set-payload-changed/ - old-set with foo's payload mutated
set -e

basedir=$(dirname "$0")/..
out=$basedir/debs
test -d "$out" -a "$out" -nt "$0" && exit 0
rm -rf "$out"
mkdir -p "$out"

# Deterministic mtime so packages are reproducible across runs.
SDE=1700000000
export SOURCE_DATE_EPOCH=$SDE

stage_root=$(mktemp -d)
trap 'rm -rf "$stage_root"' EXIT

build_deb()
{
    name=$1; outpath=$2; payload=$3; version=$4; extra=$5; postinst=$6; changelog=$7; symbols=$8
    stage=$stage_root/$$-$name-$RANDOM
    mkdir -p "$stage/DEBIAN" "$stage/usr/bin" "$stage/usr/share/doc/$name"
    printf '%s\n' "$payload" > "$stage/usr/bin/$name"
    chmod 0755 "$stage/usr/bin/$name"
    printf 'copyright text\n' > "$stage/usr/share/doc/$name/copyright"
    if test -n "$changelog" ; then
        # Plain (non-gz) changelog so the test exercises trim_release.
        printf '%s\n' "$changelog" > "$stage/usr/share/doc/$name/changelog.Debian"
    fi
    {
        printf 'Package: %s\n' "$name"
        printf 'Version: %s\n' "$version"
        printf 'Section: misc\n'
        printf 'Priority: optional\n'
        printf 'Architecture: all\n'
        printf 'Maintainer: test <test@example.com>\n'
        if test -n "$extra" ; then
            printf '%s\n' "$extra"
        fi
        printf 'Description: %s smoke-test package\n' "$name"
        printf ' Built solely to exercise pkg-diff.sh.\n'
    } > "$stage/DEBIAN/control"
    if test -n "$postinst" ; then
        printf '#!/bin/sh\n%s\n' "$postinst" > "$stage/DEBIAN/postinst"
        chmod 0755 "$stage/DEBIAN/postinst"
    fi
    if test -n "$symbols" ; then
        printf '%s\n' "$symbols" > "$stage/DEBIAN/symbols"
        chmod 0644 "$stage/DEBIAN/symbols"
    fi
    # Generate md5sums the same way dh_md5sums does: every regular
    # file outside DEBIAN/, paths relative to the package root, two
    # spaces between hash and path.
    ( cd "$stage" && find . -path ./DEBIAN -prune -o -type f -print0 |
        LC_ALL=C sort -z | xargs -0 md5sum |
        sed -e 's, \./,  ,' ) > "$stage/DEBIAN/md5sums"
    chmod 0644 "$stage/DEBIAN/md5sums"
    find "$stage" -exec touch -h -d "@$SDE" {} +
    dpkg-deb --root-owner-group --build "$stage" "$outpath" >/dev/null
    rm -rf "$stage"
}

# Standalone fixtures for cmp_deb_meta tests.
build_deb hello "$out/hello-1-0_1.0-1_all.deb" "hello world" 1.0-1 "" ""
build_deb hello "$out/hello-1-1_1.0-1_all.deb" "hello world" 1.0-1 "" ""
build_deb hello "$out/hello-1-2_1.0-1_all.deb" "hello changed" 1.0-1 "" ""
build_deb hello "$out/hello-1-3_1.0-1_all.deb" "hello world" 1.0-1 "Depends: bar" ""
build_deb hello "$out/hello-1-4_1.0-2_all.deb" "hello world" 1.0-2 "" ""
build_deb hello "$out/hello-1-5_1.0-1_all.deb" "hello world" 1.0-1 "" "echo postinst"

# Orchestrator fixture directories.
mkdir -p "$out/old-set" "$out/new-set-identical" "$out/new-set-missing" "$out/new-set-payload-changed" "$out/new-set-version-bump"
build_deb foo "$out/old-set/foo_1.0-1_all.deb" "foo body" 1.0-1 "" ""
build_deb bar "$out/old-set/bar_1.0-1_all.deb" "bar body" 1.0-1 "" ""
build_deb foo "$out/new-set-identical/foo_1.0-1_all.deb" "foo body" 1.0-1 "" ""
build_deb bar "$out/new-set-identical/bar_1.0-1_all.deb" "bar body" 1.0-1 "" ""
build_deb foo "$out/new-set-missing/foo_1.0-1_all.deb" "foo body" 1.0-1 "" ""
build_deb foo "$out/new-set-payload-changed/foo_1.0-1_all.deb" "foo CHANGED" 1.0-1 "" ""
build_deb bar "$out/new-set-payload-changed/bar_1.0-1_all.deb" "bar body" 1.0-1 "" ""
# Same content, only the package version changed - the orchestrator
# must still pair these debs by (name, arch) and report them identical.
build_deb foo "$out/new-set-version-bump/foo_1.0-2_all.deb" "foo body" 1.0-2 "" ""
build_deb bar "$out/new-set-version-bump/bar_1.0-2_all.deb" "bar body" 1.0-2 "" ""

# Reproduces the real-world scenario where only the version field of a
# Debian changelog entry changes (e.g. version-bumped rebuild produced
# from a snapshot of git).  pkg-diff.sh must normalise the changelog
# header line via trim_release before declaring a content difference.
# The trailer's build timestamp also legitimately differs across
# rebuilds and must be normalised away.
mkdir -p "$out/changelog-old" "$out/changelog-new"
old_cl='snappkg (26.999+243+g6c0c6b4-0) unstable; urgency=medium

  * Snapshot.

 -- test <test@example.com>  Mon, 12 May 2026 23:53:25 +0000'
new_cl='snappkg (26.999+244+g82d5e2d-0) unstable; urgency=medium

  * Snapshot.

 -- test <test@example.com>  Wed, 13 May 2026 22:44:27 +0000'
build_deb snappkg "$out/changelog-old/snappkg_26.999+243+g6c0c6b4-0_all.deb" "snappkg body" 26.999+243+g6c0c6b4-0 "" "" "$old_cl"
build_deb snappkg "$out/changelog-new/snappkg_26.999+244+g82d5e2d-0_all.deb" "snappkg body" 26.999+244+g82d5e2d-0 "" "" "$new_cl"

# Reproduces the real-world scenario where the package version is
# embedded in PRIVATE symbol versions inside DEBIAN/symbols.  The
# library payload is identical, only the version in the symbols file
# changes, and pkg-diff.sh must normalise via trim_release.
mkdir -p "$out/symbols-old" "$out/symbols-new"
old_sym='libfakelib.so.5 libfakelib5 #MINVER#
 FAKELIB_5_9@FAKELIB_5_9 9.12
 FAKELIB_PRIVATE@FAKELIB_PRIVATE 9.12+265+gabcdef0-0+1.1
 fakelib_get_version@FAKELIB_5.0 7.00
 fakelib_sha1@FAKELIB_PRIVATE 9.12+265+gabcdef0-0+1.1'
new_sym='libfakelib.so.5 libfakelib5 #MINVER#
 FAKELIB_5_9@FAKELIB_5_9 9.12
 FAKELIB_PRIVATE@FAKELIB_PRIVATE 9.12+265+gabcdef0-0+1.2
 fakelib_get_version@FAKELIB_5.0 7.00
 fakelib_sha1@FAKELIB_PRIVATE 9.12+265+gabcdef0-0+1.2'
build_deb libfakelib5 "$out/symbols-old/libfakelib5_9.12+265+gabcdef0-0+1.1_all.deb" "library body" 9.12+265+gabcdef0-0+1.1 "" "" "" "$old_sym"
build_deb libfakelib5 "$out/symbols-new/libfakelib5_9.12+265+gabcdef0-0+1.2_all.deb" "library body" 9.12+265+gabcdef0-0+1.2 "" "" "" "$new_sym"
