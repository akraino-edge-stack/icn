#!/usr/bin/env bash
set -eu -o pipefail

apt update
apt install -y mkisofs coreutils
# for QAT
apt install -y g++ pkg-config libelf-dev libssl1.0-dev pciutils-dev

