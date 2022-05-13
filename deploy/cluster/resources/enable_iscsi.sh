#!/usr/bin/env bash
set -eux -o pipefail

systemctl enable --now iscsid
