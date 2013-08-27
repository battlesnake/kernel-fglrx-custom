# See http://wiki.archlinux.org/index.php/VCS_PKGBUILD_Guidelines
# for more information on packaging from GIT sources.

# Maintainer: Mark K Cowan <mark@battlesnake.co.uk>
pkgname=kernel-fglrx-custom-git
pkgver=0.1
pkgrel=1
pkgdesc="Script to build a recent kernel (tested on 3.4) with patch for fglrx.  Created as I have a Radeon HD4000 series, which AMD have dropped Linux support for."
arch=('x86_64')
url="https://github.com/battlesnake/kernel-fglrx-custom"
license=('GPL2')
depends=( 'make' 'catalyst-hook' 'mkinitcpio' 'grub' )
makedepends=('git')
provides=( 'kernel-fglrx-custom' )
source=('git://github.com/battlesnake/kernel-fglrx-custom.git')
md5sums=('SKIP')

_gitroot=github.com/battlesnake/kernel-fglrx-custom
_gitname=kernel-fglrx-custom

build() {
  cd "$srcdir"
  msg "Connecting to GIT server...."

  if [[ -d "$_gitname" ]]; then
    cd "$_gitname" && git pull origin
    msg "The local files are updated."
  else
    git clone "$_gitroot" "$_gitname"
  fi

  msg "GIT checkout done or server timeout"
}

package() {
  msg "Copying script to $pkgdir/"
  cd "$srcdir/$_gitname/*.sh" "$pkgdir/"
}

# vim:set ts=2 sw=2 et:
