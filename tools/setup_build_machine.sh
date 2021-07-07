#!/usr/bin/env bash
set -eu -o pipefail

apt-get update
apt-get install -y mkisofs coreutils
# for QAT
apt-get install -y g++ pkg-config libelf-dev libssl1.0-dev pciutils-dev

