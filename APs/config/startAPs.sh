#!/bin/bash
date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf



service apache2 start

# Wlan first 6 for attacker, next 14 for AP, rest for client

#F0:9F:C2:71 ubiquiti
macchanger -m F0:9F:C2:71:22:00 wlan6 # OPN
macchanger -m F0:9F:C2:71:22:11 wlan7 # WEP
macchanger -m F0:9F:C2:71:22:22 wlan8 # PSK
macchanger -m F0:9F:C2:71:22:33 wlan9 # PSK WPS
macchanger -m F0:9F:C2:71:22:44 wlan10 # PSK VULN KRACKS TODO
macchanger -m F0:9F:C2:71:22:55 wlan11 # MGT
macchanger -m F0:9F:C2:71:22:66 wlan12 # MGT Relay
macchanger -m F0:9F:C2:71:22:77 wlan13 # MGT TLS
macchanger -m F0:9F:C2:71:22:88 wlan14 # TODO

macchanger -r wlan15     # Other 0
macchanger -r wlan16    # Other 1
macchanger -r wlan17    # Other 2
macchanger -r wlan18    # Other 3
macchanger -r wlan19    # Other 4
#macchanger -m 8d:4c:02:22:c9:33 wlan15 # Other 1
#macchanger -m 4f:c2:15:67:f1:87 wlan16 # Other 2
#macchanger -m f8:b5:cd:67:50:d5 wlan17 # Other 3
#macchanger -m 98:ab:c9:01:8d:e1 wlan18 # Other 4
#macchanger -m 76:c4:de:29:5f:b9 wlan19 # Other 5

#vwifi-client 192.168.190.15  > /root/logs/vwifi-client.log &

dnsmasq

#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGTRelay, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add 192.168.0.1/24 dev wlan6
hostapd /root/open/hostapd_open.conf > /root/logs/hostapd_open.log &

# WEP hidden
ip addr add 192.168.1.1/24 dev wlan7
hostapd /root/wep/hostapd_wep_hidden.conf > /root/logs/hostapd_wep_hidden.log &

# PSK
ip addr add 192.168.2.1/24 dev wlan8
hostapd /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log &

# PSK WPS
ip addr add 192.168.3.1/24 dev wlan9
hostapd /root/psk/hostapd_wps.conf > /root/logs/hostapd_wps.log &

# PSK krack
#ip addr add 192.168.4.1/24 dev wlan10
#/root/krack/hostapd-2.6/hostapd/hostapd /root/psk/hostapd_krack.conf > /root/logs/hostapd_krack.log &

# MGT
ip addr add 192.168.5.1/24 dev wlan11
hostapd /root/mgt/hostapd-wpe.conf > /root/logs/hostapd-wpe.log &

# MGT Relay
ip addr add 192.168.6.1/24 dev wlan12
hostapd /root/mgt/hostapd-wpe-relay.conf > /root/logs/hostapd-wpe-relay.log &

# MGT TLS
ip addr add 192.168.7.1/24 dev wlan13
hostapd /root/mgt/hostapd-wpe-tls.conf > /root/logs/hostapd-wpe-tls.log &

#TODO
#ip addr add 192.168.8.1/24 dev wlan14


# PSK Other
ip addr add 192.168.9.1/24 dev wlan15
hostapd /root/psk/hostapd_other0.conf > /root/logs/hostapd_other0.log & 

ip addr add 192.168.10.1/24 dev wlan16
hostapd /root/psk/hostapd_other1.conf > /root/logs/hostapd_other1.log & 

ip addr add 192.168.11.1/24 dev wlan17
hostapd /root/psk/hostapd_other2.conf > /root/logs/hostapd_other2.log & 

ip addr add 192.168.12.1/24 dev wlan18
hostapd /root/psk/hostapd_other3.conf > /root/logs/hostapd_other3.log & 


#ip addr del 192.168.190.15/24 dev enp0s3

#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &


#systemctl stop networking
echo "ALL SET"

#Generate WEP traffic
ping 192.168.1.2 > /dev/null 2>&1

/bin/bash

wait
