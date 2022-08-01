#!/bin/bash

envsubst_tmp (){
    for F in ./*.tmp ; do
        echo $F
        NEW=`basename $F .tmp`
        envsubst < $F > $NEW
        rm $F
    done
}

#LOAD VARIABLES FROM FILE (EXPORT)
set -a
source /root/wlan_config_aps



#Replace variables in interfaces.tmp file (one is wrong, its useless, idk :) )

envsubst < /etc/network/interfaces.tmp > /etc/network/interfaces
envsubst < /etc/dnsmasq.conf.tmp > /etc/dnsmasq.conf

# Replace var in config AP files
#OPN
cd /root/open/
envsubst_tmp
#WEP
cd /root/wep/
envsubst_tmp
#PSK
cd /root/psk/
envsubst_tmp
#WPA3
cd /root/psk/
envsubst_tmp
#MGT
cd /root/mgt/
envsubst_tmp

cd

date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

service apache2 start

# Wlan first 6 for attacker, next 14 for AP, rest for client

#F0:9F:C2:71 ubiquiti
macchanger -m $MAC_OPN $WLAN_OPN # OPN
macchanger -m $MAC_WEP $WLAN_WEP # WEP
macchanger -m $MAC_PSK $WLAN_PSK # PSK
macchanger -m $MAC_WPS $WLAN_WPS # PSK WPS
macchanger -m $MAC_KRACK $WLAN_KRACK # PSK VULN KRACKS TODO
macchanger -m $MAC_MGT $WLAN_MGT # MGT
macchanger -m $MAC_MGT2 $WLAN_MGT2 # MGT 2
macchanger -m $MAC_MGTRELAY $WLAN_MGTRELAY # MGT Relay
macchanger -m $MAC_MGTTLS $WLAN_MGTTLS # MGT TLS


macchanger -r $WLAN_OTHER0     # Other 0
macchanger -r $WLAN_OTHER1    # Other 1
macchanger -r $WLAN_OTHER2    # Other 2
macchanger -r $WLAN_OTHER3    # Other 3
macchanger -r $WLAN_WPA3    # WPA3
#macchanger -r wlan24    # TODO
macchanger -r $WLAN_NZYME    # NZYME WIDS
#macchanger -r wlan26    # TODO
#macchanger -r wlan27    # TODO
#macchanger -r wlan28    # TODO
#macchanger -r wlan29    # TODO


mkdir /root/logs/ 2> /dev/nil


bash /root/cronAPs.sh > /root/logs/cronAPs.log 2>&1 &


dnsmasq


mkdir /root/logs/ 2> /dev/nil

#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGTRelay, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add $IP_OPN.1/24 dev $WLAN_OPN
hostapd_aps /root/open/hostapd_open.conf > /root/logs/hostapd_open.log &

opennds > /root/logs/opennds.log 2>&1

# WEP hidden
ip addr add $IP_WEP.1/24 dev $WLAN_WEP
hostapd_aps /root/wep/hostapd_wep_hidden.conf > /root/logs/hostapd_wep_hidden.log &

# PSK
ip addr add $IP_PSK.1/24 dev $WLAN_PSK
hostapd_aps /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log &

# PSK WPS
ip addr add $IP_WPS.1/24 dev $WLAN_WPS
hostapd_aps /root/psk/hostapd_wps.conf > /root/logs/hostapd_wps.log &

# PSK krack
#ip addr add $IP_4.1/24 dev $WLAN_KRACK
#/root/krack/hostapd-2.6/hostapd/hostapd /root/psk/hostapd_krack.conf > /root/logs/hostapd_krack.log &

# MGT
ip addr add $IP_MGT.1/24 dev $WLAN_MGT
hostapd_aps /root/mgt/hostapd-wpe.conf > /root/logs/hostapd-wpe.log &
ip addr add $IP_MGT2.1/24 dev $WLAN_MGT2
hostapd_aps /root/mgt/hostapd-wpe2.conf > /root/logs/hostapd-wpe2.log &

# MGT Relay
ip addr add $IP_MGTRELAY.1/24 dev $WLAN_MGTRELAY
hostapd_aps /root/mgt/hostapd-wpe-relay.conf > /root/logs/hostapd-wpe-relay.log &

# MGT TLS
ip addr add $IP_MGTTLS.1/24 dev $WLAN_MGTTLS
hostapd_aps /root/mgt/hostapd-wpe-tls.conf > /root/logs/hostapd-wpe-tls.log &

#TODO
#ip addr add $IP_8.1/24 dev $WLAN_MGTTLS


# PSK Other
ip addr add $IP_OTHER0.1/24 dev $WLAN_OTHER0
hostapd_aps /root/psk/hostapd_other0.conf > /root/logs/hostapd_other0.log & 

ip addr add $IP_OTHER1.1/24 dev $WLAN_OTHER1
hostapd_aps /root/psk/hostapd_other1.conf > /root/logs/hostapd_other1.log & 

ip addr add $IP_OTHER2.1/24 dev $WLAN_OTHER2
hostapd_aps /root/psk/hostapd_other2.conf > /root/logs/hostapd_other2.log & 

ip addr add $IP_OTHER3.1/24 dev $WLAN_OTHER3
hostapd_aps /root/psk/hostapd_other3.conf > /root/logs/hostapd_other3.log & 

# WPA3 WPE
ip addr add $IP_WPA3.1/24 dev $WLAN_WPA3
#hostapd_aps /root/wpa3/hostapd-wpa3.conf > /root/logs/hostapd_wpa3.log &

#ip addr del $IP_190.15/24 dev enp0s3

#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &

#Generate WEP traffic
ping $IP_WEP.2 > /dev/null 2>&1 &

#systemctl stop networking
echo "ALL SET"


/bin/bash


wait
