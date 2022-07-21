#!/bin/bash

while : 
do
    # Verify IP correct
    VAR=`ip -br -4 a sh | grep enp0s3 | awk '{print $3}'`
    if [[ ${VAR} != "192.168.190.14/24" ]] ; then
        ip addr add 192.168.190.14/24 dev enp0s3
    fi
done