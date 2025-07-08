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

# Get ZFS checksum
curl -JLO "https://github.com/openzfs/zfs/releases/download/${zfs_tag}/${zfs_tag}.sha256.asc"
zfs_checksum="$(gpg --decrypt ${zfs_tag}.sha256.asc 2> /dev/null | cut -d' ' -f1)"

# Modify the PKGBUILD to include ZFS
install_license='install -Dm644 ${srcdir}/'"${zfs_tag}"'/LICENSE "${pkgdir}/usr/share/licenses/${pkgname}/CDDL"'

cat << EOF >> PKGBUILD
pkgdesc='Linux ZEN with ZFS'
license+=('custom:CDDL')
source+=("https://github.com/openzfs/zfs/releases/download/${zfs_tag}/${zfs_tag}.tar.gz")
sha256sums+=('${zfs_checksum}')
unset b2sums

eval "prepare() {
  inner_\$(declare -f "prepare")
  inner_prepare
"'
  echo "Adding ZFS to tree..."
  make prepare
  cd "\${srcdir}/${zfs_tag}"
  ./autogen.sh
  ./configure CC=gcc --prefix=/usr --sysconfdir=/etc --sbindir=/usr/bin \
    --libdir=/usr/lib --datadir=/usr/share --includedir=/usr/include \
    --with-udevdir=/lib/udev --libexecdir=/usr/lib/zfs --with-config=kernel \
    --enable-linux-builtin=yes --with-linux="\${srcdir}/\${_srcname}" --with-linux-obj="\${srcdir}/\${_srcname}"
  ./copy-builtin "\${srcdir}/\${_srcname}"
  cd "\${srcdir}/\${_srcname}"
  ./scripts/config -e ZFS
}'

for _p in "\${pkgname[@]::2}"; do
  eval "package_\${_p}() {
    inner_\$(declare -f "package_\${_p}")
    inner_package_\${_p}
  "'
    install -Dm644 "\${srcdir}/${zfs_tag}/LICENSE" "\${pkgdir}/usr/share/licenses/\${pkgname}/CDDL"
  }'
done
EOF

sed -i "s/pkgbase=.*/pkgbase=linux-zz/" PKGBUILD

