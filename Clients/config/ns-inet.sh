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

NS="ns-client"
VETH="veth2"
VPEER="vpeer2"
VETH_ADDR="10.200.2.1"
VPEER_ADDR="10.200.2.2"

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

echo "Waiting for APs (10 secs)"
sleep 10 # wait for AP docker

# Add WiFi interfaces wlan 40-69. Resolve the PHY from the exact interface
# name; a broad grep can select the wrong radio (for example wlan4 also
# matches wlan40). Fail immediately when a client radio is not available so
# the container healthcheck does not report a misleading "healthy" state.
CLIENT_RADIOS=0
for I in `seq 40 69` ; do
    WLAN="wlan${I}"
    PHY="$(cat "/sys/class/net/${WLAN}/phy80211/name" 2>/dev/null)"
    if [[ -z "$PHY" ]]; then
        echo "ERROR: no PHY found for Clients interface ${WLAN}" >&2
        exit 1
    fi

    echo "Assigning ${PHY} (${WLAN}) to ${NS}"
    if ! iw phy "$PHY" set netns name "/run/netns/${NS}"; then
        echo "ERROR: could not assign ${PHY} (${WLAN}) to ${NS}" >&2
        exit 1
    fi
    CLIENT_RADIOS=$((CLIENT_RADIOS + 1))
done
echo "Clients radio assignment: ${CLIENT_RADIOS}/30 PHY devices (wlan40-wlan69)"

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

# Do not flush the shared FORWARD or NAT tables here.  The AP namespace is
# configured by another script in the same host network namespace; flushing
# either table would remove the AP namespace's internet-sharing rules.
# Keep the lab rules idempotent so restarting this container does not create
# duplicate entries.
if [[ -n "$IFACE" ]]; then
   iptables -t nat -C POSTROUTING -s ${VPEER_ADDR}/24 -o ${IFACE} -j MASQUERADE 2>/dev/null || \
      iptables -t nat -A POSTROUTING -s ${VPEER_ADDR}/24 -o ${IFACE} -j MASQUERADE
   iptables -C FORWARD -i ${IFACE} -o ${VETH} -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -i ${IFACE} -o ${VETH} -j ACCEPT
   iptables -C FORWARD -o ${IFACE} -i ${VETH} -j ACCEPT 2>/dev/null || \
      iptables -A FORWARD -o ${IFACE} -i ${VETH} -j ACCEPT
fi

# Get into namespace and exec startAP
ip netns exec ${NS} /bin/bash /root/startClients.sh --rcfile <(echo "PS1=\"${NS}> \"")
#ip netns exec ${NS} /bin/bash --rcfile <(echo "PS1=\"${NS}> \"")

# if closed
