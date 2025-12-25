#!/bin/sh
set -e

wget -qO- "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xc8ec952e2a0e1fbdc5090f6a2c277a0a352154e5" | gpg --dearmor -o /usr/share/keyrings/toolchain.gpg
gpg --keyserver keyserver.ubuntu.com --recv-keys 3B4FE6ACC0B21F32
gpg --export 3B4FE6ACC0B21F32 > /usr/share/keyrings/ubuntu.gpg
for release in bionic focal; do
  echo "deb [ signed-by=/usr/share/keyrings/ubuntu.gpg ] $(cat /etc/apt/sources.list.d/ubuntu.sources | grep -m1 -oP '(?<=^URIs: ).*') $release main" >> /etc/apt/sources.list.d/toolchain.list
done
apt update
tar -xf *.tar.gz
