#!/bin/bash
date >> /root/date.log
echo 'nameserver 8.8.8.8' > /etc/resolv.conf

sleep 5

sudo modprobe mac80211_hwsim radios=13


macchanger -m 10:F9:6F:07:6C:00 wlan0
macchanger -m 10:F9:6F:BA:6C:11 wlan1
macchanger -m 10:F9:6F:BA:18:22 wlan2

macchanger -m 28:6C:07:6F:F9:33 wlan3
macchanger -m 28:6C:07:6F:F9:44 wlan4

macchanger -m B4:99:BA:6F:F9:55 wlan5
macchanger -m 78:C1:A7:BF:72:66 wlan6

macchanger -m 80:18:44:BF:72:77 wlan7
macchanger -m B0:72:BF:B0:78:88 wlan8
macchanger -m B0:72:BF:44:B0:99 wlan9

macchanger -m 10:F9:6F:AC:53:10 wlan10

macchanger -m 10:F9:6F:AC:53:11 wlan11
macchanger -m 10:F9:6F:AC:53:12 wlan12

sleep 5

vwifi-client 192.168.190.15 > /root/vwifi-client.log &

sleep 15

bash /root/cronClients.sh > /root/cronClients.log &

ip addr del 192.168.190.15/24 dev enp0s3
bash /root/checkVWIFI.sh > /root/checkVWIFI.log &

# WPA SUPPLICANT OUPUT TO FILE
# Reconnect to send the Identity and check certificate always

# Delete logs to >> always
rm /root/wpa_supplicantMSCHAP.log 2> /dev/nill
rm /root/wpa_supplicantGTC.log 2> /dev/nill
rm /root/wpa_supplicantMSCHAP_relay.log 2> /dev/nill
rm /root/wpa_supplicantTLS.log 2> /dev/nill

# MGT .5
while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_supplicant -Dnl80211 -iwlan0 -c /root/mgtClient/wpa_mschapv2.conf >> /root/wpa_supplicantMSCHAP.log &
    wait $!
done &

while :
do
    TIMEOUT=$(( ( RANDOM % 120 )  + 60 ))
    sudo timeout -k 1s ${TIMEOUT}s wpa_supplicant -Dnl80211 -iwlan1 -c /root/mgtClient/wpa_gtc.conf  >> /root/wpa_supplicantGTC.log &
    wait $!
done &

# MGT Reg .6
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_supplicant -Dnl80211 -iwlan10 -c /root/mgtClient/wpa_mschapv2_relay.conf >> /root/wpa_supplicantMSCHAP_relay.log &
    wait $!
done &

# MGT client TLS .7
while :
do
    TIMEOUT=$(( ( RANDOM % 150 )  + 300 ))
    sudo timeout -k 1s ${TIMEOUT}s  wpa_supplicant -Dnl80211 -iwlan2 -c /root/mgtClient/wpa_TLS.conf >> /root/wpa_supplicantTLS.log &
    wait $!
done &
# Wait for this ID at the end
LAST=$!

# PSK .2
sudo wpa_supplicant -Dnl80211 -iwlan3 -c /root/pskClient/wpa_psk.conf > /root/wpa_supplicantPSK3.log &
sudo wpa_supplicant -Dnl80211 -iwlan4 -c /root/pskClient/wpa_psk.conf > /root/wpa_supplicantPSK4.log &

sudo wpa_supplicant -Dnl80211 -iwlan5 -c /root/pskClient/wpa_psk_noAP.conf > /root/wpa_supplicantNoAP5.log &
sudo wpa_supplicant -Dnl80211 -iwlan6 -c /root/pskClient/wpa_psk_noAP.conf > /root/wpa_supplicantNoAP6.log &

# OPEN .0
sudo wpa_supplicant -Dnl80211 -iwlan7 -c /root/openClient/open_supplicant.conf > /root/wpa_supplicantOpen7.log &
sudo wpa_supplicant -Dnl80211 -iwlan8 -c /root/openClient/open_supplicant.conf > /root/wpa_supplicantOpen8.log &
sudo wpa_supplicant -Dnl80211 -iwlan9 -c /root/openClient/open_supplicant.conf > /root/wpa_supplicantOpen9.log &

sleep 10

ping 192.168.0.1 > /dev/nill &
ping 192.168.1.1 > /dev/nill &
ping 192.168.2.1 > /dev/nill &

sleep 10 && echo "ALL SET" &

wait $LAST