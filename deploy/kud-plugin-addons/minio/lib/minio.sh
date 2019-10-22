#!/bin/bash

function setup_mc {
    wget_mc=`wget https://dl.min.io/client/mc/release/linux-amd64/mc`
    result=$wget_mc
    if [ "$?" != 0 ]; then
        return 1
    fi
    chmod +x ./mc
    mc_add=`./mc config host add mhost http://localhost:9000 ICN-ACCESSKEYID ICN-SECRETACCESSKEY`
    result=$(echo $mc_add | grep successfully)
    if [ "$result" != "" ]; then
        return 0
    else
        return 1
    fi
}

function get_object_size {
    #echo "Check the object size of bucket: $1, object: $2.\n"

    mc_ls=`./mc ls --json mhost/$1/$2`
    size=$(echo $mc_ls | grep size | sed 's/.*"size":\([0-9]*\).*/\1/g')

    if [ "$size" != "" ]; then
        echo $((10#${size}))
        return 0
    else
        echo 0
        return 1
    fi
}

#setup_mc
#echo "setup mhost result: $?"

# example test for bucket: binary, object: mc
#mc mb mhost/binary
#mc cp ./mc mhost/binary
# echo '$? = '"$?"
#size=$(get_object_size binary mc)
#echo "size = $size"

