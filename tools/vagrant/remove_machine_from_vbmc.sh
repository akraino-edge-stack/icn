#!/bin/bash
set -eu -o pipefail

index=$1
site=$2
name=$3

vbmc --no-daemon delete ${site}-${name} || true
