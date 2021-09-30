#!/usr/bin/env bash
set -eu -o pipefail

LIBDIR="$(dirname "$(dirname "$(dirname "$PWD")")")"

eval "$(go env)"

source $LIBDIR/env/lib/common.sh

declare -i timeout=60
declare -i interval=60

function check_provisioned {
    declare -i prev_host_state=0
    declare -i j=0
    echo "Baremetal state: 1 means provisioned & 0 means not yet provisioned"
    while IFS=',' read -r name ipmi_username ipmi_password ipmi_address boot_mac os_username os_password os_image_name; do
        declare -i current_host_state=0
        state=$(kubectl get baremetalhosts $name -n metal3 -o json | jq -r '.status.provisioning.state')
        echo "Baremetal host metal3 state - "$name" : "$state

        if [ "$state" == "provisioned" ];then
            current_host_state=1
        fi

        echo "Baremetal $name     current_host_state : "$current_host_state
        echo "Previous Baremetals prev_host_state    : "$prev_host_state

         if [ $j -eq 0 ]; then
            prev_host_state=$current_host_state
            ((j+=1))
            continue
        fi

        if [ $current_host_state -eq 1 ] && [ $prev_host_state -eq 1 ]; then
            prev_host_state=1
        else
            prev_host_state=0
        fi

        echo "All Baremetal hosts aggregated state - prev_host_state:"$prev_host_state
        ((j+=1))
    done
    return $prev_host_state
}

function warm_up_time {
    echo "Wait for 240s for all baremetal hosts to reboot and network is up"
    sleep 4m
}

function wait_for_provisioned {
    declare -i k=1
    while ((timeout > 0)); do
        echo "Try $k iteration : Wait for $interval seconds to check all bmh state"
        sleep $interval
        if ! list_nodes | check_provisioned; then
            echo "All the Baremetal hosts are provisioned - success"
            warm_up_time
            exit 0
        fi
        ((timeout-=1))
        ((k+=1))
    done
    exit 1
}

function verify_bm_hosts {
    wait_for_provisioned
}

verify_bm_hosts
