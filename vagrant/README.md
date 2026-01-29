# Create WiFiChallenge Lab 2.0 using Vagrant

``` bash
# Core (reload provisioner)
vagrant plugin install vagrant-reload

# Providers
vagrant plugin install vagrant-vmware-desktop
vagrant plugin install vagrant-hyperv
vagrant plugin install vagrant-qemu

# Optional helper for VirtualBox Guest Additions
vagrant plugin install vagrant-vbguest

# Show installed plugins
vagrant plugin list
```

## For VirtualBox

Create and start the VM (about 1 hour 30 minutes):

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
Create and start the VM (about 1 hour 30 minutes)::

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

## After create VM

- SSH as user and as vagrant to configure GUI 
- Remove /etc/fstab share folder if used
