#!/usr/bin/env bash
set -eu -o pipefail

# Log output automatically
# referred from metal3 project
LOGDIR="$(dirname $0)/logs"
if [ ! -d "$LOGDIR" ]; then
    mkdir -p "$LOGDIR"
fi
LOGFILE="$LOGDIR/$(basename $0 .sh)-$(date +%F-%H%M%S).log"
exec 1> >( tee "${LOGFILE}" ) 2>&1
