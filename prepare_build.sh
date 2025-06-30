#!/bin/bash

set -e

# Use the official linux-zen PKGBUILD
git clone --depth 1 'https://gitlab.archlinux.org/archlinux/packaging/packages/linux-zen.git' build
cd build
gpg --import keys/pgp/*.asc

# Check if the kernel version is supported
zfs_tag=$(curl -Ls -o /dev/null -w %{url_effective} 'https://github.com/openzfs/zfs/releases/latest')
zfs_tag=${zfs_tag##*/}

curl -JLO "https://raw.githubusercontent.com/openzfs/zfs/refs/tags/${zfs_tag}/META"
kernel_ver=$(sed -n 's/pkgver=\([0-9][0-9]*\.[0-9][0-9]*\).*/\1/p' PKGBUILD)
kernel_max=$(awk -F': *' '$1 == "Linux-Maximum" { print $2 }' META)

echo "Using zfs version: ${zfs_tag}"

# Currently this check assumes that the versions do not need to be checked more than up to the minor version
if [ "$kernel_ver" != "$(echo -e "${kernel_max}\n${kernel_ver}" | sort -V | head -n1)" ]; then
	echo "Error: the kernel version is ${kernel_ver}, but ${zfs_tag} only supports kernels up to version ${kernel_max}."
	exit 1
fi

# Check if the linux-zen maintainer changed something other then pkgver, sha256sums or b2sums
pkgbuild_checksum=$(sed -z \
	-e "s/pkgver=[a-zA-Z0-9.\-_]*\n*//" \
	-e "s/sha256sums=([a-zA-Z0-9'\n\t ]*)\n*//" \
	-e "s/b2sums=([a-zA-Z0-9'\n\t ]*)\n*//" \
	PKGBUILD | sha256sum | cut -d " " -f 1)

echo "Comparing with PKGBUILD hash: ${pkgbuild_checksum}"

if [ "${PKGBUILD_SHA256SUM}" != "${pkgbuild_checksum}" ]; then
	echo "Error: hash did not match. Manual intervention is required"
	exit 1
fi

# Modify the PKGBUILD to include ZFS
sed -i \
    -e "s/pkgbase=linux-zen/pkgbase=linux-zz/" \
    -e "s/pkgdesc='Linux ZEN'/pkgdesc='Linux ZEN with ZFS'/" \
    -e "s/license=(GPL-2.0-only)/license=(GPL-2.0-only custom:CDDL)/" \
    -e "1s/^/_zfsver=${zfs_tag}\n/" \
    -e '$a\\nsource+=("https://github.com/openzfs/zfs/releases/download/${_zfsver}/${_zfsver}.tar.gz")\nsha256sums+=("SKIP")\nb2sums+=("SKIP")\n' \
    -e 's/\(_package[a-zA-Z0-9\-]*() *{\)/\1\n  install -Dm644 ${srcdir}\/${_zfsver}\/LICENSE "${pkgdir}\/usr\/share\/licenses\/${pkgname}\/CDDL"/' \
    -e 's/\(make -s kernelrelease > version\)/echo "Adding ZFS to tree..."; make prepare; cd ${srcdir}\/${_zfsver}; .\/autogen.sh; .\/configure CC=gcc --prefix=\/usr --sysconfdir=\/etc --sbindir=\/usr\/bin --libdir=\/usr\/lib --datadir=\/usr\/share --includedir=\/usr\/include --with-udevdir=\/lib\/udev --libexecdir=\/usr\/lib\/zfs --with-config=kernel --enable-linux-builtin=yes --with-linux=${srcdir}\/${_srcname} --with-linux-obj=${srcdir}\/${_srcname}; .\/copy-builtin ${srcdir}\/${_srcname}; cd ${srcdir}\/${_srcname}; .\/scripts\/config -e ZFS\n\n  \1/' \
    PKGBUILD

