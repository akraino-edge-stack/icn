#!/usr/bin/env bash
set -eu -o pipefail

# shellcheck disable=SC1091
source lib/common.sh

declare -i timeout=30
declare -i interval=60

function check_provisioned {
    declare -i prev_host_state=0
    declare -i j=0
    echo "VM state: 1 means provisioned & 0 means not yet provisioned"
    while read -r name address user password mac; do
        declare -i current_host_state=0
        state=$(kubectl get baremetalhosts $name -n metal3 -o json | jq -r '.status.provisioning.state')
        echo "VM host metal3 state - "$name" : "$state

        if [ $state == "provisioned" ];then
            current_host_state=1
        fi

        echo "VM $name current_host_state : "$current_host_state
        echo "VMs      prev_host_state    : "$prev_host_state

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

        echo "All VM hosts aggregated state - prev_host_state:"$prev_host_state
        ((j+=1))
    done
    return $prev_host_state
}

function warm_up_time {
    echo "Wait for 75s for all VM to reboot and network is up"
    sleep 75
}

function wait_for_provisioned {
    declare -i k=1
    declare -i t=$timeout
    while ((t > 0)); do
        echo "Try $k/$timeout iteration : Wait for $interval seconds to check all bmh state"
        sleep $interval
        if ! list_nodes | check_provisioned; then
            echo "All the VMs are provisioned - success"
            warm_up_time
            exit 0
        fi
        ((t-=1))
        ((k+=1))
    done
    exit 1
}

function verify_bm_hosts {
    wait_for_provisioned
}

verify_bm_hosts
