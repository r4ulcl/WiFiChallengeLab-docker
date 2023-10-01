#!/bin/bash

# TODO move to Dockerfile
envsubst_tmp (){
    for F in ./*.tmp ; do
        #DO it only first time
        if [ "$F" != '/*.tmp' ]; then 
            #echo $F
            NEW=`basename $F .tmp`
            envsubst < $F > $NEW
            rm $F 2> /dev/nil
        fi
    done
}

#LOAD VARIABLES FROM FILE (EXPORT)
set -a
source /root/wlan_config_aps



#Replace variables in interfaces.tmp file (one is wrong, its useless, idk :) )

envsubst < /etc/network/interfaces.tmp > /etc/network/interfaces
envsubst < /etc/dnsmasq.conf.tmp > /etc/dnsmasq.conf
envsubst < /etc/opennds/opennds.conf.tmp > /etc/opennds/opennds.conf

# Replace var in config AP files
#OPN
cd /root/open/
envsubst_tmp
#PSK
cd /root/psk/
envsubst_tmp
#WPA3
cd /root/wpa3/
envsubst_tmp
#MGT
cd /root/mgt/
envsubst_tmp
#WEP
cd /root/wep/
envsubst_tmp

cd

date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

service apache2 start > /root/logs/apache2.log 2>&1 &

# Wlan first 6 for attacker, next 14 for AP, rest for client

#F0:9F:C2:71 ubiquiti
macchanger -m $MAC_OPN $WLAN_OPN > /root/logs/macchanger.log # OPN
macchanger -m $MAC_OPN_HIDDEN $WLAN_OPN_HIDDEN > /root/logs/macchanger.log # OPN
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log # WEP
macchanger -m $MAC_PSK $WLAN_PSK >> /root/logs/macchanger.log # PSK
macchanger -m $MAC_WPS $WLAN_WPS >> /root/logs/macchanger.log # PSK WPS
macchanger -m $MAC_KRACK $WLAN_KRACK >> /root/logs/macchanger.log # PSK VULN KRACKS TODO

macchanger -m $MAC_MGT $WLAN_MGT >> /root/logs/macchanger.log # MGT
macchanger -m $MAC_MGT2 $WLAN_MGT2 >> /root/logs/macchanger.log # MGT 2
macchanger -m $MAC_MGTRELAY $WLAN_MGTRELAY >> /root/logs/macchanger.log # MGT Relay
macchanger -m $MAC_MGTRELAY_TABLETS $WLAN_MGTRELAY_TABLETS >> /root/logs/macchanger.log # MGT Relay tablets

macchanger -m $MAC_MGTTLS $WLAN_MGTTLS >> /root/logs/macchanger.log # MGT TLS

macchanger -r $WLAN_OTHER0  >> /root/logs/macchanger.log # Other 0
macchanger -r $WLAN_OTHER1 >> /root/logs/macchanger.log # Other 1
macchanger -r $WLAN_OTHER2 >> /root/logs/macchanger.log # Other 2
macchanger -r $WLAN_OTHER3 >> /root/logs/macchanger.log # Other 3
macchanger -m $MAC_BRUTEFORCE $WLAN_BRUTEFORCE >> /root/logs/macchanger.log # WPA3 Bruteforce
macchanger -m $MAC_DOWNGRADE $WLAN_DOWNGRADE >> /root/logs/macchanger.log # WPA3 DOWNGRADE
#macchanger -r wlan24 >> /root/logs/macchanger.log # TODO
macchanger -r $WLAN_NZYME >> /root/logs/macchanger.log # NZYME WIDS
#macchanger -r wlan26 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_MGT_LEGACY $WLAN_MGT_LEGACY >> /root/logs/macchanger.log # TODO
#macchanger -r wlan28 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log # TODO


mkdir /root/logs/ 2> /dev/nil


bash /root/cronAPs.sh > /root/logs/cronAPs.log 2>&1 &



mkdir /root/logs/ 2> /dev/nil

#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGTRelay, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add $IP_OPN.1/24 dev $WLAN_OPN
hostapd_aps /root/open/hostapd_open.conf > /root/logs/hostapd_open.log &
# opennds
opennds > /root/logs/opennds.log 2>&1

# Open hidden
ip addr add $IP_OPN_HIDDEN.1/24 dev $WLAN_OPN_HIDDEN
hostapd_aps /root/open/hostapd_open_hidden.conf > /root/logs/hostapd_open_hidden.log &

# PSK
ip addr add $IP_PSK.1/24 dev $WLAN_PSK
hostapd_aps /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log &

# MGT
ip addr add $IP_MGT.1/24 dev $WLAN_MGT
hostapd_aps /root/mgt/hostapd_wpe.conf > /root/logs/hostapd_wpe.log &
ip addr add $IP_MGT2.1/24 dev $WLAN_MGT2
hostapd_aps /root/mgt/hostapd_wpe2.conf > /root/logs/hostapd_wpe2.log &

# MGT Relay
ip addr add $IP_MGTRELAY.1/24 dev $WLAN_MGTRELAY
hostapd_aps /root/mgt/hostapd_wpe_relay.conf > /root/logs/hostapd_wpe_relay.log &

# MGT Relay tablets
ip addr add $IP_MGTRELAY_TABLETS.1/24 dev $WLAN_MGTRELAY_TABLETS
hostapd_aps /root/mgt/hostapd_wpe_relay_tablets.conf > /root/logs/hostapd_wpe_relay_tablets.log &

# MGT TLS
ip addr add $IP_MGTTLS.1/24 dev $WLAN_MGTTLS
hostapd_aps /root/mgt/hostapd_wpe_tls.conf > /root/logs/hostapd_wpe_tls.log &

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
ip addr add $IP_BRUTEFORCE.1/24 dev $WLAN_BRUTEFORCE
hostapd_aps /root/wpa3/hostapd_bruteforce.conf > /root/logs/hostapd_bruteforce.log &

ip addr add $IP_DOWNGRADE.1/24 dev $WLAN_DOWNGRADE
hostapd_aps /root/wpa3/hostapd_downgrade.conf > /root/logs/hostapd_downgrade.log &

ip addr add $IP_WEP.1/24 dev $WLAN_WEP
hostapd_aps /root/wep/hostapd_wep.conf > /root/logs/hostapd_wep.log &

#ip addr del $IP_190.15/24 dev enp0s3

#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &

#Generate WEP traffic
ping $IP_WEP.2 > /dev/null 2>&1 &

# start captive portal open network
sudo systemctl enable dnsmasq
service dnsmasq start

#systemctl stop networking
echo "ALL SET"

#Generate WEP traffic
ping $IP_WEP.2 > /dev/null 2>&1

/bin/bash

wait
