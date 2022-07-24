#!/bin/bash
date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

#sleep 5

#sudo modprobe mac80211_hwsim radios=13
#26-45
macchanger -m 10:F9:6F:07:6C:00 wlan26
macchanger -m 10:F9:6F:BA:6C:11 wlan27
macchanger -m 10:F9:6F:BA:18:22 wlan28

macchanger -m 28:6C:07:6F:F9:33 wlan29
macchanger -m 28:6C:07:6F:F9:44 wlan30

macchanger -m B4:99:BA:6F:F9:55 wlan31
macchanger -m 78:C1:A7:BF:72:66 wlan32

macchanger -m 80:18:44:BF:72:77 wlan33
macchanger -m B0:72:BF:B0:78:88 wlan34
macchanger -m B0:72:BF:44:B0:99 wlan35

macchanger -m 10:F9:6F:AC:53:10 wlan36

macchanger -m 10:F9:6F:AC:53:11 wlan37
macchanger -m 10:F9:6F:AC:53:12 wlan38

#TODO
macchanger -r wlan38
macchanger -r wlan39
macchanger -r wlan40
macchanger -r wlan41
macchanger -r wlan42
macchanger -r wlan43
macchanger -r wlan44
macchanger -r wlan45

sleep 5

#vwifi-client 192.168.190.15 > /root/logs/vwifi-client.log &

#sleep 15

bash /root/cronClients.sh > /root/logs/cronClients.log &

#ip addr del 192.168.190.15/24 dev enp0s3
#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &

# WPA SUPPLICANT OUPUT TO FILE
# Reconnect to send the Identity and check certificate always

# Delete logs to >> always
rm /root/logs/ 2> /dev/nill

# MGT .5
while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -iwlan26 -c /root/mgtClient/wpa_mschapv2.conf >> /root/logs/wpa_wifichallenge_supplicantMSCHAP.log &
    wait $!
done &

while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_wifichallenge_supplicant -Dnl80211 -iwlan27 -c /root/mgtClient/wpa_gtc.conf  >> /root/logs/wpa_wifichallenge_supplicantGTC.log &
    wait $!
done &

# MGT Reg .6
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -iwlan36 -c /root/mgtClient/wpa_mschapv2_relay.conf >> /root/logs/wpa_wifichallenge_supplicantMSCHAP_relay.log &
    wait $!
done &

# MGT client TLS .7
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_wifichallenge_supplicant -Dnl80211 -iwlan28 -c /root/mgtClient/wpa_TLS.conf >> /root/logs/wpa_wifichallenge_supplicantTLS.log &
    wait $!
done &
# Wait for this ID at the end
LAST=$!

# PSK .2
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan29 -c /root/pskClient/wpa_psk.conf > /root/logs/wpa_wifichallenge_supplicantPSK3.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan30 -c /root/pskClient/wpa_psk.conf > /root/logs/wpa_wifichallenge_supplicantPSK4.log &

sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan31 -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/wpa_wifichallenge_supplicantNoAP5.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan32 -c /root/pskClient/wpa_psk_noAP.conf > /root/logs/wpa_wifichallenge_supplicantNoAP6.log &

# OPEN .0
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan33 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen7.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan34 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen8.log &
sudo wpa_wifichallenge_supplicant -Dnl80211 -iwlan35 -c /root/openClient/open_supplicant.conf > /root/logs/wpa_wifichallenge_supplicantOpen9.log &

sleep 10

ping 192.168.0.1 > /dev/nill &
ping 192.168.1.1 > /dev/nill &
ping 192.168.2.1 > /dev/nill &

sleep 10 && echo "ALL SET" &

/bin/bash

wait $LAST