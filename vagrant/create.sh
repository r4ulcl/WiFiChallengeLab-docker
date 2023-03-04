#!/bin/bash

HALT=true
#HALT=false

OPTION=$1

if [ -z "${OPTION}" ]; then
    echo "Unknown option, only VMware or VirtualBox"
    exit 1
fi

if [ "$OPTION" == "vmware" ]; then
    echo "VMware"
    vagrant destroy vmware_vm --force
    echo "$D Start vmware_vm " | tee -a date.log 
    vagrant up vmware_vm 
    D=`date`
    echo "$D Finish vmware_vm " | tee -a date.log 
    
    # Configure background, etc
    timeout 30s vagrant ssh vmware_vm
    if [ "$HALT" = true ] ; then
        vagrant halt vmware_vm
    fi

elif [ $OPTION == "virtualbox" ]; then
    echo "VirtualBox"
    vagrant destroy virtualbox_vm --force
    echo "$D Start virtualbox_vm " | tee -a date.log 
    vagrant up virtualbox_vm 
    echo "$D Finish virtualbox_vm " | tee -a date.log 
    # Configure background, etc
    timeout 30s vagrant ssh virtualbox_vm
    if [ "$HALT" = true ] ; then
        vagrant halt virtualbox_vm 
    fi

elif [ $OPTION == "both" ]; then
    echo "both same time"
    echo $0
    # Start vmware
    bash $0 vmware &
    LAST1=$! 
    # Start vbox
    bash $0 virtualbox &
    LAST2=$! 

    #Wait for them
    wait $LAST1
    wait $LAST2

else
    echo "Unknown option, only VMware or VirtualBox or both"
    exit 1
fi




exit 0





