#!/usr/bin/env bash
#
# Download mac80211_hwsim.{c,h} for the running kernel *and*
# apply WiFiChallengeLab customisations to mac80211_hwsim.c.
#
# 1. Detect the running kernel’s major.minor version.
# 2. Fetch the correct files from git.kernel.org into /tmp/mac80211_hwsim.
# 3. Patch mac80211_hwsim.c with:
#       - MODULE_VERSION line
#       - rewritten hwsim_mon_xmit()
#       - early ACK check in mac80211_hwsim_addr_match()
#       - extra monitor-ACK handling in the TX path
#       - Dragondrain PoC flood detection per interface
#
#
# Tested in ubuntu 5.4.0-204-generic, ubuntu 6.8.0-65-generic and kali 6.12.25-amd64

set -euo pipefail

# 0. Destination directory
DEST="./"
mkdir -p "$DEST"

# 1. Work out the running kernel’s branch and the sub-directory that
#    holds mac80211_hwsim.{c,h} on git.kernel.org
kernel_full=$(uname -r)                 # e.g. 6.5.0-17-generic
IFS=. read -r kmaj kmin _ <<< "$kernel_full"
branch="linux-${kmaj}.${kmin}.y"        # e.g. linux-6.5.y

if (( kmaj > 6 || (kmaj == 6 && kmin >= 4) )); then
    subdir="drivers/net/wireless/virtual"
else
    subdir="drivers/net/wireless"
fi

base_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/${subdir}"
files=(mac80211_hwsim.c mac80211_hwsim.h)

printf "Kernel branch:  %s\nSource path:    %s\n" "$branch" "$subdir"

# 2. Download the two source files (only if not already present)
for f in "${files[@]}"; do
    url="${base_url}/${f}?h=${branch}"
    dst="${DEST}/${f}"
    if [[ -f "$dst" ]]; then
        echo "  - $f already exists, skipping download"
        continue
    fi
    printf '  - Downloading %s ...\n' "$f"
    curl -fsSL "$url" -o "$dst"
done
echo "Sources are in ${DEST}"

# 3. Patch mac80211_hwsim.c
CFILE="${DEST}/mac80211_hwsim.c"
[[ -f "$CFILE" ]] || { echo "ERROR: ${CFILE} not found, aborting" >&2; exit 1; }

# Optional backup
cp "$CFILE" "$CFILE.bak"
echo "  - Backup created at ${CFILE}.bak"

# 3-A  MODULE_VERSION ---------------------------------------------------
if ! grep -q 'WiFiChallengeLab-version' "$CFILE"; then
    sed -i '/MODULE_LICENSE("GPL");/a MODULE_VERSION("2.4-WiFiChallengeLab-version");' "$CFILE"
    echo "  - MODULE_VERSION added"
else
    echo "  - MODULE_VERSION already present"
fi

# 3-B  Rewrite hwsim_mon_xmit() ----------------------------------------
if ! grep -q 'mac80211_hwsim_tx_frame(data->hw' "$CFILE"; then
    # Replace from function header down to the first closing brace.
    sed -i -n ':a;N;$!ba;s#static netdev_tx_t hwsim_mon_xmit[^}]*}#static netdev_tx_t hwsim_mon_xmit(struct sk_buff *skb,\n\t\t\t\t\tstruct net_device *dev)\n{\n\tstruct mac80211_hwsim_data *data = netdev_priv(dev);\n\t/* fall back to the normal mac80211 transmit routine */\n\tmac80211_hwsim_tx_frame(data->hw, skb, data->channel);\n\treturn NETDEV_TX_OK;\n}#g' "$CFILE"
    echo "  - hwsim_mon_xmit() replaced"
else
    echo "  - hwsim_mon_xmit() already patched"
fi

# 3-C  Early ACK check in addr_match() ---------------------------------
if ! grep -q 'ACK if destination is our permanent MAC' "$CFILE"; then
    # Insert after the opening brace of the function.
    awk '
    /static bool mac80211_hwsim_addr_match/ {print; infunc=1; next}
    infunc && /^\s*\{/ {
        print "{";
        print "\t/* ACK if destination is our permanent MAC (even with only monitor IFs). */";
        print "\tif (ether_addr_equal(addr, data->addresses[0].addr) ||";
        print "\t    ether_addr_equal(addr, data->addresses[1].addr))";
        print "\t\treturn true;";
        infunc=0; next
    }
    {print}
    ' "$CFILE" > "${CFILE}.tmp" && mv "${CFILE}.tmp" "$CFILE"
    echo "  - Early ACK match code inserted"
else
    echo "  - addr_match() already patched"
fi

# 3-D  Extra monitor-ACK handling in TX path ---------------------------
if ! grep -q 'deliver the frame to every hwsim radio' "$CFILE"; then
    sed -i '/data->tx_bytes += skb->len;/a \
\t/* deliver the frame to every hwsim radio on the same channel */' "$CFILE"
    echo "  - Comment before ack = ... added"
else
    echo "  - Comment before ack already present"
fi

if ! grep -q 'Forward an IEEE' "$CFILE"; then
    sed -i '/ack = mac80211_hwsim_tx_frame_no_nl/a \
\t/* Forward an IEEE 802.11 ACK frame to the monitor as well */\n\tif (ack)\n\t\tmac80211_hwsim_monitor_ack(channel, hdr->addr2);\n' "$CFILE"
    echo "  - Extra monitor-ACK block inserted"
else
    echo "  - Extra monitor-ACK block already present"
fi

# 3-E  Dragonblood PoC per-interface flood detection -------------------
# 3-E-1 Extend struct mac80211_hwsim_data with PoC fields
if ! grep -q "poc_attack_triggered" "$CFILE"; then
    sed -i '/struct mac80211_hwsim_data {/a \
    /* PoC flood detection (per interface) */\
    bool poc_attack_triggered;\
    int poc_auth_counter;\
    unsigned long poc_last_jiffies;\
    int poc_flood_streak;\
    int poc_quiet_streak;\
' "$CFILE"
    echo "  - PoC per-interface fields added to struct mac80211_hwsim_data"
else
    echo "  - PoC per-interface fields already present"
fi

# 3-E-2 Ensure header for ieee80211_mgmt and related macros
if ! grep -q "ieee80211_mgmt" "$CFILE"; then
  sed -i '/#include <linux\/etherdevice.h>/a #include <net/mac80211.h>' "$CFILE"
  echo "  - mac80211 header include added"
else
  echo "  - mac80211 header include already present"
fi

# 3-E-3 Insert detection and drop logic (per-interface state)
if ! grep -q "\[HWSIM-POC\]" "$CFILE"; then
    sed -i '/mac80211_hwsim_monitor_rx(hw, skb, channel);/a \
\t{\
\t\tstruct mac80211_hwsim_data *data = hw->priv;\
\t\tstruct ieee80211_hdr *hdr = (struct ieee80211_hdr *)skb->data;\
\t\tu16 fc = le16_to_cpu(hdr->frame_control);\
\t\tunsigned long now = jiffies;\
\t\t/* Count auth frames per second */\
\t\tif (ieee80211_is_auth(fc)) {\
\t\t\tif (time_before(now, data->poc_last_jiffies + HZ)) {\
\t\t\t\tdata->poc_auth_counter++;\
\t\t\t} else {\
\t\t\t\tif (data->poc_auth_counter > 20) {\
\t\t\t\t\tdata->poc_flood_streak++;\
\t\t\t\t\tdata->poc_quiet_streak = 0;\
\t\t\t\t\tpr_info("[HWSIM-POC][%s] Flood window (%d/5)\\n",\
\t\t\t\t\t\twiphy_name(hw->wiphy), data->poc_flood_streak);\
\t\t\t\t} else {\
\t\t\t\t\tif (data->poc_attack_triggered) data->poc_quiet_streak++;\
\t\t\t\t\telse data->poc_quiet_streak = 0;\
\t\t\t\t\tdata->poc_flood_streak = 0;\
\t\t\t\t}\
\t\t\t\tif (data->poc_flood_streak >= 5 && !data->poc_attack_triggered) {\
\t\t\t\t\tdata->poc_attack_triggered = true;\
\t\t\t\t\tpr_info("[HWSIM-POC][%s] Flood 5s -> vuln mode ON\\n",\
\t\t\t\t\t\twiphy_name(hw->wiphy));\
\t\t\t\t}\
\t\t\t\tif (data->poc_attack_triggered && data->poc_quiet_streak >= 10) {\
\t\t\t\t\tdata->poc_attack_triggered = false;\
\t\t\t\t\tpr_info("[HWSIM-POC][%s] Quiet 10s -> vuln mode RESET\\n",\
\t\t\t\t\t\twiphy_name(hw->wiphy));\
\t\t\t\t}\
\t\t\t\tdata->poc_auth_counter = 1;\
\t\t\t\tdata->poc_last_jiffies = now;\
\t\t\t}\
\t\t}\
\t\t/* Drop only after trigger */\
\t\tif (data->poc_attack_triggered && ieee80211_is_data(fc)) {\
\t\t\tif (skb->len > 24) {\
\t\t\t\tconst u8 *payload = skb->data + 24; /* after 802.11 header */\
\t\t\t\tif (payload[6] == 0x88 && payload[7] == 0x8e) {\
\t\t\t\t\t/* Allow EAPOL handshake */\
\t\t\t\t} else {\
\t\t\t\t\tpr_info("[HWSIM-POC][%s] Dropping data frame len=%u\\n",\
\t\t\t\t\t\twiphy_name(hw->wiphy), skb->len);\
\t\t\t\t\tieee80211_free_txskb(hw, skb);\
\t\t\t\t\treturn;\
\t\t\t\t}\
\t\t\t}\
\t\t}\
\t}' "$CFILE"
    echo "  - Dragondrain PoC per-interface monitor patch added"
else
    echo "  - Dragondrain PoC per-interface monitor patch already present"
fi

echo "mac80211_hwsim.c patched successfully"
