#!/bin/bash

DESTROY=true
#DESTROY=false
HALT=true
#HALT=false

OPTION=$1

if [ -z "${OPTION}" ]; then
    echo "Unknown option, use vmware, virtualbox, hyper-v, qemu or all"
    exit 1
fi

if [ "$OPTION" == "vmware" ]; then
    echo "VMware"
    if [ "$DESTROY" = true ] ; then
        vagrant destroy vmware_vm --force
    fi
    D=`date`
    echo "$D Start vmware_vm " | tee -a vmware_vm.log 
    vagrant up vmware_vm 
    D=`date`
    echo "$D Finish vmware_vm " | tee -a vmware_vm.log 
    
    # Configure background, etc
    vagrant halt vmware_vm
    vagrant up vmware_vm
    timeout 30s vagrant ssh vmware_vm
    if [ "$HALT" = true ] ; then
        vagrant halt vmware_vm
    fi

elif [ "$OPTION" == "virtualbox" ]; then
    echo "VirtualBox"
    if [ "$DESTROY" = true ] ; then
        vagrant destroy virtualbox_vm --force
    fi
    D=`date`
    echo "$D Start virtualbox_vm " | tee -a virtualbox_vm.log
    vagrant up virtualbox_vm 
    D=`date`
    echo "$D Finish virtualbox_vm " | tee -a virtualbox_vm.log
    # Configure background, etc
    vagrant halt virtualbox_vm
    vagrant up virtualbox_vm
    timeout 30s vagrant ssh virtualbox_vm
    if [ "$HALT" = true ] ; then
        vagrant halt virtualbox_vm 
    fi

elif [ "$OPTION" == "hyper-v" ]; then
    echo "hyper-v"
    if [ "$DESTROY" = true ] ; then
        vagrant destroy hyper-v_vm --force
    fi
    D=`date`
    echo "$D Start hyper-v_vm " | tee -a hyper-v_vm.log
    vagrant up hyper-v_vm 
    D=`date`
    echo "$D Finish hyper-v_vm " | tee -a hyper-v_vm.log
    # Configure background, etc
    vagrant halt hyper-v_vm
    vagrant up hyper-v_vm
    timeout 30s vagrant ssh hyper-v_vm
    if [ "$HALT" = true ] ; then
        vagrant halt hyper-v_vm 
    fi

elif [ "$OPTION" == "qemu" ]; then
    echo "QEMU"
    if [ "$DESTROY" = true ] ; then
        vagrant destroy qemu_vm --provider=qemu --force
    fi
    D=`date`
    echo "$D Start qemu_vm " | tee -a qemu_vm.log
    vagrant up qemu_vm --provider=qemu
    D=`date`
    echo "$D Finish qemu_vm " | tee -a qemu_vm.log
    vagrant halt qemu_vm --provider=qemu
    vagrant up qemu_vm --provider=qemu
    timeout 30s vagrant ssh qemu_vm --provider=qemu
    if [ "$HALT" = true ] ; then
        vagrant halt qemu_vm --provider=qemu
    fi
    

elif [ $OPTION == "all" ]; then
    echo "all same time"
    echo $0
    # Start vmware
    bash $0 vmware &
    LAST1=$! 
    # Start vbox
    bash $0 virtualbox &
    LAST2=$! 

    # Start hyper-v
    bash $0 hyper-v &
    LAST3=$! 

    # Start qemu
    bash $0 qemu &
    LAST4=$!

    #Wait for them
    wait $LAST1
    wait $LAST2
    wait $LAST3
    wait $LAST4

else
    echo "Unknown option, use vmware, virtualbox, hyper-v, qemu or all"
    exit 1
fi




exit 0




