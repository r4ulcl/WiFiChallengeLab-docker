#!/bin/bash

envsubst_tmp (){
    for F in ./*.tmp ; do
        echo $F
        NEW=`basename $F .tmp`
        envsubst < $F > $NEW
        rm $F
    done
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
macchanger -m $MAC_MGT_MSCHAP $WLAN_MGT_MSCHAP
macchanger -m $MAC_MGT_GTC $WLAN_MGT_GTC
macchanger -m $MAC_TLS $WLAN_TLS

macchanger -m $MAC_WPA_PSK $WLAN_WPA_PSK
macchanger -m $MAC_WPA_PSK2 $WLAN_WPA_PSK2

macchanger -m $MAC_PSK_NOAP $WLAN_PSK_NOAP
macchanger -m $MAC_PSK_NOAP2 $WLAN_PSK_NOAP2

macchanger -m $MAC_OPN1 $WLAN_OPN1
macchanger -m $MAC_OPN2 $WLAN_OPN2
macchanger -m $MAC_OPN3 $WLAN_OPN3

macchanger -m $MAC_MGT_RELAY $WLAN_MGT_RELAY


#TODO
macchanger -r wlan51
macchanger -r wlan52
macchanger -r wlan53
macchanger -r wlan54
macchanger -r wlan55
macchanger -r wlan56
macchanger -r wlan57
macchanger -r wlan58
macchanger -r wlan59

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
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_MSCHAP -c /root/mgtClient/wpa_mschapv2.conf >> /root/logs/wpa_wifichallenge_supplicantMSCHAP.log &
    wait $!
done &

while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_GTC -c /root/mgtClient/wpa_gtc.conf  >> /root/logs/wpa_wifichallenge_supplicantGTC.log &
    wait $!
done &

# MGT Reg .6
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_MGT_RELAY -c /root/mgtClient/wpa_mschapv2_relay.conf >> /root/logs/wpa_wifichallenge_supplicantMSCHAP_relay.log &
    wait $!
done &

# MGT client TLS .7
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_TLS -c /root/mgtClient/wpa_TLS.conf >> /root/logs/wpa_wifichallenge_supplicantTLS.log &
    wait $!
done &
# Wait for this ID at the end
LAST=$!

# PSK .2
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_WPA_PSK -c /root/pskClient/wpa_psk.conf > /root/logs/wpa_wifichallenge_supplicantPSK3.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_WPA_PSK2 -c /root/pskClient/wpa_psk.conf > /root/logs/wpa_wifichallenge_supplicantPSK4.log &

sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_PSK_NOAP -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/wpa_wifichallenge_supplicantNoAP5.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_PSK_NOAP2 -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/wpa_wifichallenge_supplicantNoAP6.log &

# OPEN .0
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN1 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen7.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN2 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen8.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -i$WLAN_OPN3 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen9.log &

sleep 10

#OPN GET IP and accept captive portal
echo 'Starting OPN clients'
for N in `seq 47 49`; do
	echo "Starting wlan$N"
	dhclien-wifichallenge wlan$N 2> /dev/nill

	LOGIN=`curl --silent --interface wlan$N http://192.168.0.1:2050/login`
	# Get FAS
	URL=`echo $LOGIN | grep fas | grep -oP "(?<=href=').*?(?=')"`
	#LOGIN
	CONFIRM=`curl --silent -interface wlan$N "${URL}&username=guest1&password=password1"`
	#Get custom to confirm
	CUSTOM=`echo "$CONFIRM" |  grep 'custom' | grep -oP '(?<=value=").*?(?=")'`
	# Confirm
	CONNECTED=`curl --silent -interface wlan$N "${URL}&username=guest1&password=password1&custom=$CUSTOM&landing=yes"`

done & #Can take a while

sleep 5

ping 192.168.0.1 > /dev/nill &
ping 192.168.1.1 > /dev/nill &
ping 192.168.2.1 > /dev/nill &

sleep 10 && echo "ALL SET"

/bin/bash

wait $LAST
