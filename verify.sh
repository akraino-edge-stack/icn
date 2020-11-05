#!/usr/bin/env bash
set -eu -o pipefail

# This file is called by jenkins CI job

sudo make unit
