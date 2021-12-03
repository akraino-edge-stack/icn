#!/bin/bash
set -eu -o pipefail

site=$1
name=$2
port=$3

vbmc --no-daemon delete ${site}-${name} || true
