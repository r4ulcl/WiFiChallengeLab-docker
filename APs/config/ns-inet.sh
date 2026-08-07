#!/usr/bin/env bash
#https://gist.github.com/dpino/6c0dca1742093346461e11aa8f608a99
# set -x

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi

# Install mac80211_hwsim_WiFiChallenge if missing.
# Run WITHOUT sudo: this script already requires root (EUID check above), and
# sudo's default env_reset would strip the MAC_*/WLAN_* vars that docker-compose
# injects via env_file (there is no /root/wlan_config file). install.sh needs
# MAC_DOWNGRADE/MAC_6GHZ/MAC_OWE to scope the hwsim flood/DoS BSSID allowlist.
cd /root/mac80211_hwsim_WiFiChallenge
bash install.sh  || true

# Returns all available interfaces, except "lo" and "veth*".
available_interfaces()
{
   local ret=()

   local ifaces=$(ip li sh | cut -d " " -f 2 | tr "\n" " ")
   read -a arr <<< "$ifaces" 

   for each in "${arr[@]}"; do
      each=${each::-1}
      if [[ ${each} != "lo" && ${each} != veth* ]]; then
         ret+=( "$each" )
      fi
   done
   echo ${ret[@]}
}

# Pick the host uplink for internet sharing: the default-route interface, which
# is name independent (eth0 on the generic box, but works for ens*/enp* too).
IFACE="$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')"
if [[ -z "$IFACE" ]]; then
   # No default route: try the first ethernet that has a global IPv4 address.
   IFACE="$(ip -o -4 addr show scope global 2>/dev/null | awk '$2 ~ /^(eth|en)/ {print $2; exit}')"
fi
if [[ -n "$IFACE" ]]; then
   echo "Using uplink interface $IFACE for AP internet sharing"
else
   echo "WARNING: no uplink/default route found; APs will start WITHOUT internet sharing (offline mode)."
fi

NS="ns-ap"
VETH="veth1"
VPEER="vpeer1"
VETH_ADDR="10.200.1.1"
VPEER_ADDR="10.200.1.2"

trap cleanup EXIT

cleanup()
{
   ip li delete ${VETH} 2>/dev/null
}

# Remove namespace if it exists.
ip netns del $NS &>/dev/null

# Create namespace
ip netns add $NS


#----------------------------WiFiChallenge---------------------------------------------------------
#Check kill to avoid all problems

#airmon-ng check kill

# Define vlan for all dockers (in host, is the same mac80211_hwsim)
#0-9 for the attacker
#10-39 radios for AP
#40-69 radios for Clients
#70 for nzyme in attacker

# mac80211_hwsim_WiFiChallenge is the stock mac80211_hwsim under a new filename,
# but it still registers the SAME kernel-global resources (the MAC80211_HWSIM
# genetlink family and the mac80211_hwsim sysfs class). So it cannot coexist with
# the stock module: if stock mac80211_hwsim was autoloaded (base image / udev /
# wireless tooling, default 2 radios -> < 20 wlan), inserting our module on top
# fails with "Device or resource busy". Only (re)load when the full radio set
# isn't already up, and when we do, evict EVERY hwsim variant first.
if [[ $(iw dev | grep -c wlan) -lt 20 ]] ; then
   # Remove our renamed module and the stock one (either can hold the resources).
   sudo modprobe -r mac80211_hwsim_WiFiChallenge 2>/dev/null || true
   sudo modprobe -r mac80211_hwsim 2>/dev/null || true

   # Wait for the module to fully leave: inserting while a same-named module is
   # still in MODULE_STATE_GOING also returns EBUSY.
   for _ in $(seq 1 50); do
      lsmod | grep -q '^mac80211_hwsim' || break
      sleep 0.1
   done

   sudo modprobe mac80211_hwsim_WiFiChallenge radios=71
fi

# Rename interfaces APwlan, ClientWlan, wlan0 wlan5
#TODO?

# Add WiFi interfaces 10-39
# 6-9 are for attacker but unnused, so ap
for I in `seq 6 39` ; do
	# Exact-name phy lookup; grep wlan$I also matched wlan60-70 (I=6/7)
	[ -e /sys/class/net/wlan$I ] || continue
	PHY=$(cat /sys/class/net/wlan$I/phy80211/name 2>/dev/null)
	[ -n "$PHY" ] && iw phy "$PHY" set netns name /run/netns/$NS
done

#--------------------------------------------------------------------------------------------------


# Create veth link.
ip link add ${VETH} type veth peer name ${VPEER}

# Add peer-1 to NS.
ip link set ${VPEER} netns $NS

# Setup IP address of ${VETH}.
ip addr add ${VETH_ADDR}/24 dev ${VETH}
ip link set ${VETH} up

# Setup IP ${VPEER}.
ip netns exec $NS ip addr add ${VPEER_ADDR}/24 dev ${VPEER}
ip netns exec $NS ip link set ${VPEER} up
ip netns exec $NS ip link set lo up
ip netns exec $NS ip route add default via ${VETH_ADDR}

# Enable IP-forwarding.
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush forward rules.
iptables -P FORWARD DROP
iptables -F FORWARD
 
# Flush nat rules.
iptables -t nat -F

# Enable masquerading of 10.200.1.0/24 out the uplink (only if we have one,
# so an offline lab still starts its APs without a bogus MASQUERADE rule).
if [[ -n "$IFACE" ]]; then
   iptables -t nat -A POSTROUTING -s ${VPEER_ADDR}/24 -o ${IFACE} -j MASQUERADE
   iptables -A FORWARD -i ${IFACE} -o ${VETH} -j ACCEPT
   iptables -A FORWARD -o ${IFACE} -i ${VETH} -j ACCEPT
fi

# Get into namespace and exec startAP
ip netns exec ${NS} /bin/bash /root/startAPs.sh --rcfile <(echo "PS1=\"${NS}> \"")
#·ip netns exec ${NS} /bin/bash --rcfile <(echo "PS1=\"${NS}> \"")

# if closed
