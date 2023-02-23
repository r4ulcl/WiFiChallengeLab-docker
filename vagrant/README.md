# Create WiFiChallenge Lab 2.0 using Vagrant

## For VirtualBox

Create and start the VM (about 1 hour 40 minutes):

```bash
vagrant up virtualbox_vm
```

Connect the VM

```bash
vagrant ssh virtualbox_vm
```

Or RDP to IP 192.168.56.10 and port 3389 (using [remmina](https://remmina.org/) or other RDP client)


### Compress after install to export OVA

```
VBoxManage modifyhd --compact ubuntu-focal-20.04-cloudimg.vmdk
```


## For VMWare
Create and start the VM (about 1 hour 40 minutes)::

``` bash
vagrant up vmware_vm 
```

Connect the VM
``` bash
vagrant ssh vmware_vm 
```

Or RDP to IP 192.168.59.10 and port 3389 (using [remmina](https://remmina.org/) or other RDP client)

### Compress after install to export OVA

```
```

## After cerate VM

- SSH as user and as vagrant to configure GUI 
- Remove /etc/fstab share folder if used