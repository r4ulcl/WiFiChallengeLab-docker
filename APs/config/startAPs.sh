#!/bin/bash

# TODO move to Dockerfile
envsubst_tmp () {
    VARS=$(printf '${%s} ' \
        KEY_J3D5ETO \
        WIFICHALLENGE_VERSION \
        $(compgen -e | grep -E '^(CHANNEL_|USER_|PASS_|FLAG_|IP_|ESSID_|MAC_|WLAN_|ANON_IDENTITY_|IDENTITY_)') \
    )

    for F in ./*.tmp; do
        [ "$F" = './*.tmp' ] && continue
        NEW=$(basename "$F" .tmp)
        envsubst "$VARS" < "$F" > "$NEW"
        rm "$F" 2>/dev/null
    done
}

#LOAD VARIABLES FROM FILE (EXPORT)
set -a
source /root/wlan_config_aps

bash /root/decode_passwords.sh /root/wlan_config_aps
source /root/wlan_config_aps.clear


#Replace variables in interfaces.tmp file (one is wrong, its useless, idk :) )

#envsubst < /etc/network/interfaces.tmp > /etc/network/interfaces
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
#OWE
cd /root/owe/
envsubst_tmp

# WEB
cd /var/www/html/
envsubst_tmp

# Freeradius
cd /etc/freeradius/3.0/mods-config/files/
envsubst_tmp

rm /root/wlan_config_aps.clear

cd

date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

service apache2 start > /root/logs/apache2.log 2>&1 &

freeradius -f -l /var/log/freeradius/radius.log &

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
macchanger -m $MAC_MGT_RELAY $WLAN_MGT_RELAY >> /root/logs/macchanger.log # MGT Relay
macchanger -m $MAC_MGT_RELAY_TABLETS $WLAN_MGT_RELAY_TABLETS >> /root/logs/macchanger.log # MGT Relay tablets

macchanger -m $MAC_MGT_TLS $WLAN_MGT_TLS >> /root/logs/macchanger.log # MGT TLS

macchanger -r $WLAN_OTHER0  >> /root/logs/macchanger.log # Other 0
macchanger -r $WLAN_OTHER1 >> /root/logs/macchanger.log # Other 1
macchanger -r $WLAN_OTHER2 >> /root/logs/macchanger.log # Other 2
macchanger -r $WLAN_OTHER3 >> /root/logs/macchanger.log # Other 3
macchanger -m $MAC_BRUTEFORCE $WLAN_BRUTEFORCE >> /root/logs/macchanger.log # WPA3 Bruteforce
macchanger -m $MAC_DOWNGRADE $WLAN_DOWNGRADE >> /root/logs/macchanger.log # WPA3 DOWNGRADE
macchanger -m $MAC_6GHZ $WLAN_6GHZ >> /root/logs/macchanger.log # WPA3 6ghz
#macchanger -r wlan24 >> /root/logs/macchanger.log # TODO
macchanger -r $WLAN_NZYME >> /root/logs/macchanger.log # NZYME WIDS
#macchanger -r wlan26 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_MGT_MD5 $WLAN_MGT_MD5 >> /root/logs/macchanger.log # TODO
#macchanger -r wlan28 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_OWE $WLAN_OWE >> /root/logs/macchanger.log # TODO


mkdir /root/logs/ 2> /dev/nil


bash /root/cronAPs.sh > /root/logs/cronAPs.log 2>&1 &


#chmod +x patch_deauth_on_drop_dmesg.sh
bash  /root/patch_deauth_on_drop_dmesg.sh /run/hostapd- 5  > /root/logs/patch_deauth_on_drop_dmesg.log 2>&1 &


mkdir /root/logs/ 2> /dev/nil

#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGT_RELAY, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add $IP_OPN.1/24 dev $WLAN_OPN
host_aps_apd /root/open/hostapd_open.conf > /root/logs/hostapd_open.log &
# opennds
opennds > /root/logs/opennds.log 2>&1

# Open hidden
ip addr add $IP_OPN_HIDDEN.1/24 dev $WLAN_OPN_HIDDEN
host_aps_apd /root/open/hostapd_open_hidden.conf > /root/logs/hostapd_open_hidden.log &

# PSK
ip addr add $IP_PSK.1/24 dev $WLAN_PSK
host_aps_apd /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log &

# PSK WPS
ip addr add $IP_WPS.1/24 dev $WLAN_WPS
host_aps_apd /root/psk/hostapd_wps.conf > /root/logs/hostapd_wps.log &

# MGT
ip addr add $IP_MGT.1/24 dev $WLAN_MGT
host_aps_apd /root/mgt/hostapd_wpe.conf > /root/logs/hostapd_wpe.log &
ip addr add $IP_MGT2.1/24 dev $WLAN_MGT2
host_aps_apd /root/mgt/hostapd_wpe2.conf > /root/logs/hostapd_wpe2.log &

# MGT Relay
ip addr add $IP_MGT_RELAY.1/24 dev $WLAN_MGT_RELAY
host_aps_apd /root/mgt/hostapd_wpe_relay.conf > /root/logs/hostapd_wpe_relay.log &

# MGT Relay tablets
ip addr add $IP_MGT_RELAY_TABLETS.1/24 dev $WLAN_MGT_RELAY_TABLETS
host_aps_apd /root/mgt/hostapd_wpe_relay_tablets.conf > /root/logs/hostapd_wpe_relay_tablets.log &

# MGT TLS
ip addr add $IP_MGT_TLS.1/24 dev $WLAN_MGT_TLS
host_aps_apd /root/mgt/hostapd_wpe_tls.conf > /root/logs/hostapd_wpe_tls.log &


# MGT MD5
ip addr add $IP_MGT_MD5.1/24 dev $WLAN_MGT_MD5
host_aps_apd /root/mgt/hostapd_wpe_md5.conf > /root/logs/hostapd_wpe_md5.log &

#TODO
#ip addr add $IP_8.1/24 dev $WLAN_MGT_TLS


# PSK Other
ip addr add $IP_OTHER0.1/24 dev $WLAN_OTHER0
host_aps_apd /root/psk/hostapd_other0.conf > /root/logs/hostapd_other0.log & 

ip addr add $IP_OTHER1.1/24 dev $WLAN_OTHER1
host_aps_apd /root/psk/hostapd_other1.conf > /root/logs/hostapd_other1.log & 

ip addr add $IP_OTHER2.1/24 dev $WLAN_OTHER2
host_aps_apd /root/psk/hostapd_other2.conf > /root/logs/hostapd_other2.log & 

ip addr add $IP_OTHER3.1/24 dev $WLAN_OTHER3
host_aps_apd /root/psk/hostapd_other3.conf > /root/logs/hostapd_other3.log & 

# WPA3 WPE
ip addr add $IP_BRUTEFORCE.1/24 dev $WLAN_BRUTEFORCE
host_aps_apd /root/wpa3/hostapd_bruteforce.conf > /root/logs/hostapd_bruteforce.log &

ip addr add $IP_DOWNGRADE.1/24 dev $WLAN_DOWNGRADE
host_aps_apd /root/wpa3/hostapd_downgrade.conf > /root/logs/hostapd_downgrade.log &

ip addr add $IP_6GHZ.1/24 dev $WLAN_6GHZ
host_aps_apd /root/wpa3/hostapd_6ghz.conf > /root/logs/hostapd_6ghz.log &

# WEP
ip addr add $IP_WEP.1/24 dev $WLAN_WEP
host_aps_apd /root/wep/hostapd_wep.conf > /root/logs/hostapd_wep.log &


# OWE
ip addr add $IP_OWE.1/24 dev $WLAN_OWE
host_aps_apd /root/owe/hostapd_owe.conf > /root/logs/hostapd_owe.log &

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
