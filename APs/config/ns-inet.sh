#!/usr/bin/env bash
#https://gist.github.com/dpino/6c0dca1742093346461e11aa8f608a99
# set -x

if [[ $EUID -ne 0 ]]; then
    echo "You must be root to run this script"
    exit 1
fi

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

IFACE="$1"
#FORCE IFACE
IFACE=`ip route show | grep 'default via' | awk '{print $5}'`
if [[ -z "$IFACE" ]]; then
   ifaces=($(available_interfaces))
   if [[ ${#ifaces[@]} -gt 0 ]]; then
      IFACE=${ifaces[0]}
      echo "Using interface $IFACE"
   else
      echo "Usage: ./ns-inet <IFACE>"
      exit 1
   fi
else
   IFACE=`ip route show | grep 'default via' | awk '{print $5}'`
   echo "Using interface $IFACE"
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
#40-59 radios for Clients
#60 for nzyme in attacker

#if wlan < 20 (AP wifis) no executed 
if [[ $(iw dev | grep wlan | wc -l) -lt 20 ]] ; then
   sudo modprobe mac80211_hwsim -r
fi

sudo modprobe mac80211_hwsim radios=61

# Rename interfaces APwlan, ClientWlan, wlan0 wlan5
#TODO?

# Add WiFi interfaces 10-39
# 6-9 are for attacker but unnused, so ap
for I in `seq 6 39` ; do
	PHY=`ls /sys/class/ieee80211/*/device/net/ | grep -B1 wlan$I | grep -Eo 'phy[0-9]+'`
	iw phy $PHY set netns name /run/netns/$NS
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

# Enable masquerading of 10.200.1.0.
iptables -t nat -A POSTROUTING -s ${VPEER_ADDR}/24 -o ${IFACE} -j MASQUERADE
 
iptables -A FORWARD -i ${IFACE} -o ${VETH} -j ACCEPT
iptables -A FORWARD -o ${IFACE} -i ${VETH} -j ACCEPT

# Get into namespace and exec startAP
ip netns exec ${NS} /bin/bash /root/startAPs.sh --rcfile <(echo "PS1=\"${NS}> \"")
#·ip netns exec ${NS} /bin/bash --rcfile <(echo "PS1=\"${NS}> \"")

# if closed
