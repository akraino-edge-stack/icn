#!/usr/bin/env bash

apt update
apt install -y mkisofs coreutils
# for QAT
apt install -y g++ pkg-config libelf-dev libssl1.0-dev pciutils-dev

