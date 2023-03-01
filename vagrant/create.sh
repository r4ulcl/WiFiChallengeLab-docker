#!/bin/bash

#HALT=true
HALT=false

OPTION=$1

if [ -z "${OPTION}" ]; then
    echo "Unknown option, only VMware or VirtualBox"
    exit 1
fi

if [ "$OPTION" == "vmware" ]; then
    echo "VMware"
    vagrant destroy vmware_vm --force
    echo 'Start vmware_vm' >> ~/date.log 
    date >> ~/date.log 
    vagrant up vmware_vm 
    date >> ~/date.log 
    if [ "$HALT" = true ] ; then
        vagrant halt vmware_vm
    fi

elif [ $OPTION == "virtualbox" ]; then
    echo "VirtualBox"
    vagrant destroy virtualbox_vm --force
    echo 'Start virtualbox_vm' >> date.log 
    date >> ~/date.log 
    vagrant up virtualbox_vm 
    date >> ~/date.log 
    if [ "$HALT" = true ] ; then
        vagrant halt virtualbox_vm 
    fi

else
    echo "Unknown option, only VMware or VirtualBox"
    exit 1
fi


exit 0





