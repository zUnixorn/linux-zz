#!/bin/bash

set -e

cd /build

if [ "$(nproc)" -gt 1 ]; then
	sudo sed -i 's/#MAKEFLAGS="-j2"/MAKEFLAGS="-j'$(nproc)'"/g' /etc/makepkg.conf
fi

makepkg --noconfirm -s

