#!/bin/bash

# TODO move to Dockerfile
envsubst_tmp () {
    VARS=$(printf '${%s} ' \
        KEY_J3D5ETO \
        WIFICHALLENGE_VERSION \
        $(compgen -e | grep -E '^(CHANNEL_|USER_|PASS_|FLAG_|IP_|ESSID_|MAC_|WLAN_|ANON_IDENTITY_|IDENTITY_|SIM_)') \
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

bash /root/decode_passwords.sh
source /root/wlan_config.clear


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

rm /root/wlan_config.clear

cd

date

echo 'nameserver 8.8.8.8' > /etc/resolv.conf

mkdir -p /root/logs/

# Self-healing apache2 supervisor.
# `service apache2 start` trusts /var/run/apache2/apache2.pid blindly: if apache2
# ever dies and that PID gets reused by an unrelated process, the init script
# thinks apache is "already running" and refuses to restart it, permanently
# wedging the login.php portal (and the container healthcheck) even though the
# container itself stays "Up". Instead of a one-shot start, run a small loop
# that health-checks the real HTTP endpoint and force-restarts apache2 whenever
# it stops answering, clearing any stale pidfile first.
supervise_apache () {
    while true; do
        if ! curl -f -s -o /dev/null --max-time 3 http://localhost/login.php; then
            echo "$(date) apache2 not responding, restarting" >> /root/logs/apache2.log
            service apache2 stop >> /root/logs/apache2.log 2>&1
            # -x (exact process-name match, no -f) so this doesn't match its own
            # argv when invoked as `bash -c "<this source>"`, which would
            # otherwise self-match and kill the watchdog loop.
            pkill -9 -x apache2 2>/dev/null
            rm -f /var/run/apache2/apache2.pid
            service apache2 start >> /root/logs/apache2.log 2>&1
        fi
        sleep 15
    done
}

rm -f /var/run/apache2/apache2.pid
service apache2 start > /root/logs/apache2.log 2>&1
supervise_apache > /root/logs/apache2_supervisor.log 2>&1 &

freeradius -f -l /var/log/freeradius/radius.log &

# Software HLR/AuC for the SIM/USIM AP (EAP-SIM/AKA/AKA').
rm -f /tmp/hlr_auc_gw.sock
hlr_auc_gw -s /tmp/hlr_auc_gw.sock -m /root/mgt/milenage_db > /root/logs/hlr_auc_gw.log 2>&1 &

# Wlan first 6 for attacker, next 14 for AP, rest for client

#F0:9F:C2:71 ubiquiti
macchanger -m $MAC_OPN $WLAN_OPN > /root/logs/macchanger.log # OPN
macchanger -m $MAC_OPN_HIDDEN $WLAN_OPN_HIDDEN >> /root/logs/macchanger.log # OPN
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log # WEP
macchanger -m $MAC_PSK $WLAN_PSK >> /root/logs/macchanger.log # PSK
macchanger -m $MAC_WPS $WLAN_WPS >> /root/logs/macchanger.log # PSK WPS
macchanger -m $MAC_KRACK $WLAN_KRACK >> /root/logs/macchanger.log # PSK VULN KRACKS TODO

macchanger -m $MAC_MGT $WLAN_MGT >> /root/logs/macchanger.log # MGT
macchanger -m $MAC_MGT2 $WLAN_MGT2 >> /root/logs/macchanger.log # MGT 2
macchanger -m $MAC_MGT_RELAY $WLAN_MGT_RELAY >> /root/logs/macchanger.log # MGT Relay
macchanger -m $MAC_MGT_RELAY_TABLETS $WLAN_MGT_RELAY_TABLETS >> /root/logs/macchanger.log # MGT Relay tablets

macchanger -m $MAC_MGT_TLS $WLAN_MGT_TLS >> /root/logs/macchanger.log # MGT TLS
macchanger -m $MAC_MGT_SIM $WLAN_MGT_SIM >> /root/logs/macchanger.log # MGT SIM/AKA'

macchanger -r $WLAN_OTHER0  >> /root/logs/macchanger.log # Other 0
macchanger -r $WLAN_OTHER1 >> /root/logs/macchanger.log # Other 1
macchanger -r $WLAN_OTHER2 >> /root/logs/macchanger.log # Other 2
macchanger -r $WLAN_OTHER3 >> /root/logs/macchanger.log # Other 3
macchanger -m $MAC_BRUTEFORCE $WLAN_BRUTEFORCE >> /root/logs/macchanger.log # WPA3 Bruteforce
macchanger -m $MAC_DOWNGRADE $WLAN_DOWNGRADE >> /root/logs/macchanger.log # WPA3 DOWNGRADE
macchanger -m $MAC_6GHZ $WLAN_6GHZ >> /root/logs/macchanger.log # WPA3 6ghz
#macchanger -r wlan24 >> /root/logs/macchanger.log # TODO
#macchanger -r wlan26 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_MGT_MD5 $WLAN_MGT_MD5 >> /root/logs/macchanger.log # TODO
#macchanger -r wlan28 >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_WEP $WLAN_WEP >> /root/logs/macchanger.log # TODO
macchanger -m $MAC_OWE $WLAN_OWE >> /root/logs/macchanger.log # TODO

# Campus PMKID AP (wifi-campus): single BSSID, client-less PMKID
macchanger -m $MAC_ROAM1 $WLAN_ROAM1 >> /root/logs/macchanger.log # ROAM AP1




bash /root/cronAPs.sh > /root/logs/cronAPs.log 2>&1 &


#chmod +x patch_deauth_on_drop_dmesg.sh
bash  /root/patch_deauth_on_drop_dmesg.sh /run/hostapd- 5  > /root/logs/patch_deauth_on_drop_dmesg.log 2>&1 &



#TODO RE ORDER ALL WLAN and IP -> 0 OPN, 1 WEP, 2 PSK, 3 PSK WPS, 4 MGT, 5 MGT_RELAY, 6 MGT TLS, 7 8 , 9,10,11,12,13 others

# Open
ip addr add $IP_OPN.1/24 dev $WLAN_OPN
host_aps_apd /root/open/hostapd_open.conf > /root/logs/hostapd_open.log 2>&1 &
# opennds
opennds > /root/logs/opennds.log 2>&1

# Open hidden
ip addr add $IP_OPN_HIDDEN.1/24 dev $WLAN_OPN_HIDDEN
host_aps_apd /root/open/hostapd_open_hidden.conf > /root/logs/hostapd_open_hidden.log 2>&1 &

# PSK
ip addr add $IP_PSK.1/24 dev $WLAN_PSK
host_aps_apd /root/psk/hostapd_wpa.conf > /root/logs/hostapd_wpa.log 2>&1 &

# PSK WPS
ip addr add $IP_WPS.1/24 dev $WLAN_WPS
host_aps_apd /root/psk/hostapd_wps.conf > /root/logs/hostapd_wps.log 2>&1 &

# Campus PMKID AP (wifi-campus): single AP on WPA2-PSK.
# Client-less PMKID target: no client is attached on purpose.
ip addr add $IP_ROAM1.1/24 dev $WLAN_ROAM1
host_aps_apd /root/psk/hostapd_pmkid.conf > /root/logs/hostapd_pmkid.log 2>&1 &

# MGT — wifi-corp as a real roaming ESS (L2 bridge)
# AP1 (wlan15) and AP2 (wlan16) advertise the same ESSID on the same channel but
# are TWO BSSIDs. Instead of giving each radio its own /24, both are enslaved to a
# single Linux bridge (br-mgt) so they form ONE L2 segment. Only the bridge holds
# the gateway IP ($IP_MGT.1 = 192.168.5.1), so a client reaches the SAME portal no
# matter which AP it associates to or roams between. Each hostapd adds its wlan to
# br-mgt via the 'bridge=br-mgt' line in its config, so the bridge must exist
# BEFORE hostapd starts (hostapd enslaves the iface after switching it to AP mode).
ip link add name br-mgt type bridge
# Pin the bridge MAC so the gateway's L2 address is stable (a bridge otherwise
# adopts the lowest port MAC as radios enslave, changing the gateway MAC mid-run).
ip link set br-mgt address $MAC_MGT
ip link set br-mgt up
ip addr add $IP_MGT.1/24 dev br-mgt
host_aps_apd /root/mgt/hostapd_wpe.conf > /root/logs/hostapd_wpe.log 2>&1 &
host_aps_apd /root/mgt/hostapd_wpe2.conf > /root/logs/hostapd_wpe2.log 2>&1 &

# MGT Relay
ip addr add $IP_MGT_RELAY.1/24 dev $WLAN_MGT_RELAY
host_aps_apd /root/mgt/hostapd_wpe_relay.conf > /root/logs/hostapd_wpe_relay.log 2>&1 &

# MGT Relay tablets
ip addr add $IP_MGT_RELAY_TABLETS.1/24 dev $WLAN_MGT_RELAY_TABLETS
host_aps_apd /root/mgt/hostapd_wpe_relay_tablets.conf > /root/logs/hostapd_wpe_relay_tablets.log 2>&1 &

# MGT TLS
ip addr add $IP_MGT_TLS.1/24 dev $WLAN_MGT_TLS
host_aps_apd /root/mgt/hostapd_wpe_tls.conf > /root/logs/hostapd_wpe_tls.log 2>&1 &


# MGT MD5
ip addr add $IP_MGT_MD5.1/24 dev $WLAN_MGT_MD5
host_aps_apd /root/mgt/hostapd_wpe_md5.conf > /root/logs/hostapd_wpe_md5.log 2>&1 &

# MGT SIM / AKA / AKA'
ip addr add $IP_MGT_SIM.1/24 dev $WLAN_MGT_SIM
host_aps_apd /root/mgt/hostapd_wpe_sim.conf > /root/logs/hostapd_wpe_sim.log 2>&1 &

#TODO
#ip addr add $IP_8.1/24 dev $WLAN_MGT_TLS


# PSK Other
ip addr add $IP_OTHER0.1/24 dev $WLAN_OTHER0
host_aps_apd /root/psk/hostapd_other0.conf > /root/logs/hostapd_other0.log 2>&1 &

ip addr add $IP_OTHER1.1/24 dev $WLAN_OTHER1
host_aps_apd /root/psk/hostapd_other1.conf > /root/logs/hostapd_other1.log 2>&1 &

ip addr add $IP_OTHER2.1/24 dev $WLAN_OTHER2
host_aps_apd /root/psk/hostapd_other2.conf > /root/logs/hostapd_other2.log 2>&1 &

ip addr add $IP_OTHER3.1/24 dev $WLAN_OTHER3
host_aps_apd /root/psk/hostapd_other3.conf > /root/logs/hostapd_other3.log 2>&1 &

# WPA3 WPE
ip addr add $IP_BRUTEFORCE.1/24 dev $WLAN_BRUTEFORCE
host_aps_apd /root/wpa3/hostapd_bruteforce.conf > /root/logs/hostapd_bruteforce.log 2>&1 &

ip addr add $IP_DOWNGRADE.1/24 dev $WLAN_DOWNGRADE
host_aps_apd /root/wpa3/hostapd_downgrade.conf > /root/logs/hostapd_downgrade.log 2>&1 &

ip addr add $IP_6GHZ.1/24 dev $WLAN_6GHZ
host_aps_apd /root/wpa3/hostapd_6ghz.conf > /root/logs/hostapd_6ghz.log 2>&1 &

# WEP
ip addr add $IP_WEP.1/24 dev $WLAN_WEP
host_aps_apd /root/wep/hostapd_wep.conf > /root/logs/hostapd_wep.log 2>&1 &


# OWE
ip addr add $IP_OWE.1/24 dev $WLAN_OWE
host_aps_apd /root/owe/hostapd_owe.conf > /root/logs/hostapd_owe.log 2>&1 &

# Per-AP signal variation is done in the driver (mac80211_hwsim.c, patched by
# patch80211.sh): each radio gets a small, stable per-radio RSSI offset so every
# BSSID shows a distinct PWR. Done in the kernel so it is immune to the hostapd
# txpower race an `iw set txpower` loop hit here.

#ip addr del $IP_190.15/24 dev enp0s3

#bash /root/checkVWIFI.sh > /root/logs/checkVWIFI.log &

#Generate WEP traffic
ping $IP_WEP.2 > /dev/null 2>&1 &

# dnsmasq is supervised by cronAPs.sh (sole owner); do not start it here

#systemctl stop networking
echo "ALL SET"

#Generate WEP traffic
ping $IP_WEP.2 > /dev/null 2>&1

/bin/bash

wait
