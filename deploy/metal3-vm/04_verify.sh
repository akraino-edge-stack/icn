#!/usr/bin/env bash

set -x

# shellcheck disable=SC1091
source lib/common.sh

node=0
declare -i timeout=30
declare -i interval=60

function check_num_hosts {
    while read -r name address user password mac; do
        ((node+=1))
    done
    return $node
}

function check_bm_state {
    c=1
    n=$1
    while [ $c -le $n ]
    do
        echo "Welcone $c times"
        (( c++ ))
    done
}

function check_provisioned {
    declare -i prev_host_state=0
    declare -i j=0
    while read -r name address user password mac; do
        declare -i current_host_state=0
        state=$(kubectl get baremetalhosts $name -n metal3 -o json | jq -r '.status.provisioning.state')
        echo $name":"$state

        if [ $state == "provisioned" ];then
            current_host_state=1
        fi

        echo "j:"$j
        echo "current_host_state":$current_host_state
        echo "prev_host_state":$prev_host_state

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

        echo "after:prev_host_state:"$prev_host_state
        ((j+=1))
    done
    return $prev_host_state
}

function wait_for_provisioned {
    all_bmh_provisioned=1
    while ((timeout > 0)); do
        echo "Try $timeout: Wait for $interval seconds to check all bmh state"
        sleep $interval
        list_nodes | check_provisioned
        all_bmh_state=$?
        if [[ $all_bmh_state -eq $all_bmh_provisioned ]]; then
            echo "All the bmh state is provisioned - vsuccess"
            exit 0
        fi
        ((timeout-=1))
    done
    exit 1
}

function verify_bm_hosts {
    #list_nodes | check_num_hosts
    #nodes=$?
    #check_bm_state $nodes
    wait_for_provisioned
}

verify_bm_hosts
