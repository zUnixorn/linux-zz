#!/bin/bash

# Use the official linux-zen PKGBUILD
git clone --depth 1 'https://gitlab.archlinux.org/archlinux/packaging/packages/linux-zen.git' build
cd build
gpg --import keys/pgp/*.asc

# Check if the linux-zen maintainer changed something other then pkgver, sha256sums or b2sums
pkgbuild_checksum=$(sed -z \
	-e "s/pkgver=[a-zA-Z0-9.\-_]*\n*//" \
	-e "s/sha256sums=([a-zA-Z0-9'\n\t ]*)\n*//" \
	-e "s/b2sums=([a-zA-Z0-9'\n\t ]*)\n*//" \
	PKGBUILD | sha256sum | cut -d " " -f 1)

# TODO fail if it does not match the previous checksum

# Modify the PKGBUILD to include ZFS
sed -i \
    -e "s/pkgbase=linux-zen/pkgbase=linux-zz/" \
    -e "s/pkgdesc='Linux ZEN'/pkgdesc='Linux ZEN with ZFS'/" \
    -e "s/license=(GPL-2.0-only)/license=(GPL-2.0-only LicenseRef-CDDL)/" \
    -e "1s/^/_zfsver=2.3.3\n/" \
    -e '$a\\nsource+=("https://github.com/openzfs/zfs/releases/download/zfs-${_zfsver}/zfs-${_zfsver}.tar.gz")\nsha256sums+=("SKIP")\nb2sums+=("SKIP")\n' \
    -e 's/\(  rm "$modulesdir"\/build\)/\1\n\n  echo "Adding ZFS to tree..."; make prepare; cd ${srcdir}\/zfs-${_zfsver}; .\/autogen.sh; .\/configure CC=gcc --prefix=\/usr --sysconfdir=\/etc --sbindir=\/usr\/bin --libdir=\/usr\/lib --datadir=\/usr\/share --includedir=\/usr\/include --with-udevdir=\/lib\/udev --libexecdir=\/usr\/lib\/zfs --with-config=kernel --enable-linux-builtin=yes --with-linux=${srcdir}\/${_srcname} --with-linux-obj=${srcdir}\/${_srcname}; .\/copy-builtin ${srcdir}\/${_srcname}; cd ${srcdir}\/${_srcname}; .\/scripts\/config -e ZFS/' \
    PKGBUILD

# Update .SRCINFO
makepkg --printsrcinfo > .SRCINFO

# TODO do actual build
