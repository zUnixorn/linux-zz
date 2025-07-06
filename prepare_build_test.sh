#!/bin/bash

# This may be removed at a later date
# Currently it is used for testing parts of the pipeline, since building the entire kernel for minor changes is infeasable

set -e

cd /build

curl -JLO 'https://aur.archlinux.org/cgit/aur.git/plain/PKGBUILD?h=paru-bin'

makepkg --printsrcinfo > .SRCINFO

