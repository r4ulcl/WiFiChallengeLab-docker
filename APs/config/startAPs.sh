#!/bin/bash
date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf



service apache2 start

# Wlan first 6 for attacker, next 14 for AP, rest for client

#F0:9F:C2:71 ubiquiti
macchanger -m F0:9F:C2:71:22:00 wlan10 # OPN
macchanger -m F0:9F:C2:71:22:11 wlan11 # WEP
macchanger -m F0:9F:C2:71:22:22 wlan12 # PSK
macchanger -m F0:9F:C2:71:22:33 wlan13 # PSK WPS
macchanger -m F0:9F:C2:71:22:44 wlan14 # PSK VULN KRACKS TODO
macchanger -m F0:9F:C2:71:22:55 wlan15 # MGT
macchanger -m F0:9F:C2:71:22:5A wlan16 # MGT 2
macchanger -m F0:9F:C2:71:22:66 wlan17 # MGT Relay
macchanger -m F0:9F:C2:71:22:77 wlan18 # MGT TLS


macchanger -r wlan19     # Other 0
macchanger -r wlan20    # Other 1
macchanger -r wlan21    # Other 2
macchanger -r wlan22    # Other 3
#macchanger -r wlan23    # TODO
#macchanger -r wlan24    # TODO
macchanger -r wlan25    # NZYME WIDS
#macchanger -r wlan26    # TODO
#macchanger -r wlan27    # TODO
#macchanger -r wlan28    # TODO
#macchanger -r wlan29    # TODO


mkdir /root/logs/ 2> /dev/nil

#Start nzyme
service postgresql start
sudo ip link set wlan25 down
sudo iw wlan25 set monitor control
sudo ip link set wlan25 up
bash /usr/share/nzyme/bin/nzyme > /root/logs/nzyme.log 2>&1  &

#vwifi-client 192.168.190.15  > /root/logs/vwifi-client.log &

bash /root/cronAPs.sh > /root/logs/cronAPs.log 2>&1 &


dnsmasq


mkdir /root/logs/ 2> /dev/nil

#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGTRelay, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add 192.168.0.1/24 dev wlan10
hostapd_aps /root/open/hostapd_open.conf > /root/logs/hostapd_open.log &

# WEP hidden
ip addr add 192.168.1.1/24 dev wlan11
hostapd_aps /root/wep/hostapd_wep_hidden.conf > /root/logs/hostapd_wep_hidden.log &

# PSK
ip addr add 192.168.2.1/24 dev wlan12
hostapd_aps /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log &

# PSK WPS
ip addr add 192.168.3.1/24 dev wlan13
hostapd_aps /root/psk/hostapd_wps.conf > /root/logs/hostapd_wps.log &

# PSK krack
#ip addr add 192.168.4.1/24 dev wlan14
#/root/krack/hostapd-2.6/hostapd/hostapd /root/psk/hostapd_krack.conf > /root/logs/hostapd_krack.log &

# MGT
ip addr add 192.168.5.1/24 dev wlan15
hostapd_aps /root/mgt/hostapd-wpe.conf > /root/logs/hostapd-wpe.log &
ip addr add 192.168.5.1/24 dev wlan16
hostapd_aps /root/mgt/hostapd-wpe2.conf > /root/logs/hostapd-wpe2.log &

# MGT Relay
ip addr add 192.168.6.1/24 dev wlan17
hostapd_aps /root/mgt/hostapd-wpe-relay.conf > /root/logs/hostapd-wpe-relay.log &

# MGT TLS
ip addr add 192.168.7.1/24 dev wlan18
hostapd_aps /root/mgt/hostapd-wpe-tls.conf > /root/logs/hostapd-wpe-tls.log &

#TODO
#ip addr add 192.168.8.1/24 dev wlan18


# PSK Other
ip addr add 192.168.9.1/24 dev wlan19
hostapd_aps /root/psk/hostapd_other0.conf > /root/logs/hostapd_other0.log & 

ip addr add 192.168.10.1/24 dev wlan20
hostapd_aps /root/psk/hostapd_other1.conf > /root/logs/hostapd_other1.log & 

ip addr add 192.168.11.1/24 dev wlan21
hostapd_aps /root/psk/hostapd_other2.conf > /root/logs/hostapd_other2.log & 

ip addr add 192.168.12.1/24 dev wlan22
hostapd_aps /root/psk/hostapd_other3.conf > /root/logs/hostapd_other3.log & 


#ip addr del 192.168.190.15/24 dev enp0s3

#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &


#systemctl stop networking
echo "ALL SET"

#Generate WEP traffic
ping 192.168.1.2 > /dev/null 2>&1

/bin/bash

wait
