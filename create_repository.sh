#!/bin/bash

set -e

sudo mkdir -p /repository
sudo chown "$(id -u):$(id -g)" /repository
mv /build/*.pkg.tar.* /repository
cd /repository

echo -n "$GPG_SIGNING_KEY" | base64 -d | gpg --import -

find . -type f -iname '*.pkg.tar.*' -not -iname '*.sig' -print -exec gpg --batch --yes --detach-sign --use-agent -u "$GPG_KEY_ID" {} \;
find . -type f -iname '*.pkg.tar.*' -not -iname '*.sig' -print0 | xargs -0 repo-add -k "$GPG_KEY_ID" -s -v "${REPOSITORY:-linux-zz}.db.tar.zst"

sudo chown root:root ./*
sudo mv ./* /output

