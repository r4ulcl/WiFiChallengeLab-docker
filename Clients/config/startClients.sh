#!/bin/bash -x

envsubst_tmp (){
    for F in ./*.tmp ; do
        echo $F
        NEW=`basename $F .tmp`
        envsubst < $F > $NEW
        rm $F
    done
}

function retry { 
    $1 && echo "success" || (echo "fail" && retry $1) 
}


function opnConnect {
    WLAN=$1
    IP=$2
    IP_OPN1=192.168.10
	echo "Starting $WLAN"
	retry "dhclien-wifichallenge $WLAN" 2> /dev/nill

    sleep 10
    curl --silent http://$IP_OPN1.1 -L


	# Remove IP to avoid Ip conflict
    echo start clean IP
    dhclien-wifichallenge $WLAN -r
    kill `ps aux | grep "dhclien-wifichallenge $WLAN" | grep -v grep | head -n 1 | awk '{print $2}'` # kill dhclient for this WLAN
    
    ip addr flush dev $WLAN
    echo end clean IP

    ifconfig $WLAN $IP/24 
    echo "DONE $WLAN"
}

date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

#LOAD VARIABLES FROM FILE (EXPORT)
set -a
source /root/wlan_config_clients

#cd /root/open/
#envsubst_tmp

#sleep 5

#sudo modprobe mac80211_hwsim radios=13
#40-59
macchanger -m $MAC_MGT_MSCHAP $WLAN_MGT_MSCHAP > /root/logs/macchanger.log 
macchanger -m $MAC_MGT_GTC $WLAN_MGT_GTC >> /root/logs/macchanger.log
macchanger -m $MAC_TLS $WLAN_TLS >> /root/logs/macchanger.log
macchanger -m $MAC_TLS_PHISHING $WLAN_TLS_PHISHING >> /root/logs/macchanger.log
macchanger -m $MAC_MGT_RELAY $WLAN_MGT_RELAY >> /root/logs/macchanger.log
macchanger -m $MAC_MGT_RELAY_TABLETS_W $WLAN_MGT_RELAY_TABLETS_W >> /root/logs/macchanger.log
macchanger -m $MAC_MGT_RELAY_TABLETS $WLAN_MGT_RELAY_TABLETS >> /root/logs/macchanger.log

macchanger -m $MAC_MGT_LEGACY $WLAN_MGT_LEGACY >> /root/logs/macchanger.log

macchanger -m $MAC_WPA_PSK $WLAN_WPA_PSK >> /root/logs/macchanger.log
macchanger -m $MAC_WPA_PSK2 $WLAN_WPA_PSK2 >> /root/logs/macchanger.log

macchanger -m $MAC_PSK_NOAP $WLAN_PSK_NOAP >> /root/logs/macchanger.log
macchanger -m $MAC_PSK_NOAP2 $WLAN_PSK_NOAP2 >> /root/logs/macchanger.log

macchanger -m $MAC_OPN1 $WLAN_OPN1 >> /root/logs/macchanger.log
macchanger -m $MAC_OPN2 $WLAN_OPN2 >> /root/logs/macchanger.log
macchanger -m $MAC_OPN3 $WLAN_OPN3 >> /root/logs/macchanger.log
macchanger -m $MAC_DOWNGRADE $WLAN_DOWNGRADE >> /root/logs/macchanger.log
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log



#TODO
macchanger -r wlan56 >> /root/logs/macchanger.log
macchanger -r wlan57 >> /root/logs/macchanger.log
macchanger -r wlan58 >> /root/logs/macchanger.log
macchanger -r wlan59 >> /root/logs/macchanger.log

sleep 5

#vwifi-client 192.168.190.15 > /root/logs/vwifi-client.log &

#sleep 15

# Delete logs to >> always
mkdir /root/logs/ 2> /dev/nill
rm /root/logs/ 2> /dev/nill

# Exec cronClient
bash /root/cronClients.sh > /root/logs/cronClients.log &

#ip addr del 192.168.190.15/24 dev enp0s3
#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &

# WPA SUPPLICANT OUPUT TO FILE
# Reconnect to send the Identity and check certificate always

# MGT .5
while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_MSCHAP -c /root/mgtClient/wpa_mschapv2.conf >> /root/logs/supplicantMSCHAP.log &
    wait $!
done &

while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_GTC -c /root/mgtClient/wpa_gtc.conf  >> /root/logs/supplicantGTC.log &
    wait $!
done &

# MGT Reg .6
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_RELAY -c /root/mgtClient/wpa_mschapv2_relay.conf >> /root/logs/supplicantMSCHAP_relay.log &
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_RELAY_TABLETS_W -c /root/mgtClient/wpa_mschapv2_relay_tabletsW.conf >> /root/logs/supplicantMSCHAP_relay_tabletsW.log &
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_RELAY_TABLETS -c /root/mgtClient/wpa_mschapv2_relay_tablets.conf >> /root/logs/supplicantMSCHAP_relay_tablets.log &
    wait $!
done &

# MGT client TLS .7
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_TLS -c /root/mgtClient/wpa_TLS.conf >> /root/logs/supplicantTLS.log &
    wait $!
done &

# MGT TLS .7 phishing
while :
do
    TIMEOUT=$(( ( RANDOM % 30 )  + 30 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_TLS_PHISHING -c /root/mgtClient/wpa_TLS_phishing.conf >> /root/logs/supplicantTLS_phishing.log &
    wait $!
done &

# MGT Legacy MD5 .17
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_LEGACY -c /root/mgtClient/wpa_md5.conf >> /root/logs/supplicantMD5.log &
    wait $!
done &

# Wait for this ID at the end
LAST=$!

# PSK .2
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_WPA_PSK -c /root/pskClient/wpa_psk.conf > /root/logs/supplicantPSK.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_WPA_PSK2 -c /root/pskClient/wpa_psk.conf > /root/logs/supplicantPSK2.log &

sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_PSK_NOAP -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/supplicantNoAP.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_PSK_NOAP2 -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/supplicantNoAP2.log &

# OPEN .0
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN1 -c /root/openClient/open_supplicant.conf > /root/logs/supplicantOpen1.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN2 -c /root/openClient/open_supplicant.conf > /root/logs/supplicantOpen2.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN3 -c /root/openClient/open_supplicant.conf > /root/logs/supplicantOpen3.log &

# WPA3 .52
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_DOWNGRADE -c /root/wpa3Client/downgrade_psk.conf > /root/logs/supplicantWPA3Downgrade.log &

# WEP
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_WEP -c /root/wepClient/wep.conf > /root/logs/supplicantWEP.log &


sleep 10

#OPN GET IP and accept captive portal
opnConnect $WLAN_OPN1 $IP_OPN1.100 > /root/logs/OPNClients$WLAN_OPN1.log 2>&1 &
opnConnect $WLAN_OPN2 $IP_OPN1.101 > /root/logs/OPNClients$WLAN_OPN2.log 2>&1 &
opnConnect $WLAN_OPN3 $IP_OPN1.102 > /root/logs/OPNClients$WLAN_OPN3.log 2>&1 &

LAST2=$!

sleep 5

ping $IP_OPN1.1 > /dev/nill &
#ping -I wlan 192.168.1.1 > /dev/nill &
ping $IP_WPA_PSK.1 > /dev/nill &

sleep 10 && echo "ALL SET"

/bin/bash

wait $LAST
wait $LAST2
