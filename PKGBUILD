pkgname=build-compare
pkgver=0
pkgrel=1
pkgdesc='Compare RPM, Debian and Arch Linux package build results'
arch=('any')
url='https://github.com/openSUSE/build-compare'
license=('GPL-2.0-or-later')
depends=('bash' 'binutils' 'bzip2' 'coreutils' 'cpio' 'diffutils' 'file'
         'findutils' 'gawk' 'grep' 'gzip' 'perl' 'sed' 'tar' 'util-linux'
         'xz' 'zstd')
optdepends=('rpm-tools: compare RPM packages'
            'squashfs-tools: compare SquashFS images'
            'unzip: compare ZIP and JAR archives')
source=()
for _archive in "$pkgname"-*.tar*; do
    case $_archive in
        *.pkg.tar*|*.src.tar*) continue ;;
        *.tar|*.tar.gz) source+=("$_archive") ;;
    esac
done
sha256sums=('SKIP')

package() {
    cd "$srcdir/${source[0]%.tar*}"
    install -Dm755 -t "$pkgdir/usr/lib/build" *.sh
    install -Dm644 COPYING "$pkgdir/usr/share/licenses/$pkgname/COPYING"
}
