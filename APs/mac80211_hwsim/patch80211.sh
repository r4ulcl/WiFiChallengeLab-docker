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
    sed -i -n ':a;N;$!ba;s#static netdev_tx_t hwsim_mon_xmit[^}]*}#static netdev_tx_t hwsim_mon_xmit(struct sk_buff *skb,\n                    struct net_device *dev)\n{\n    struct mac80211_hwsim_data *data = netdev_priv(dev);\n    /* fall back to the normal mac80211 transmit routine */\n    mac80211_hwsim_tx_frame(data->hw, skb, data->channel);\n    return NETDEV_TX_OK;\n}#g' "$CFILE"
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
        print "    /* ACK if destination is our permanent MAC (even with only monitor IFs). */";
        print "    if (ether_addr_equal(addr, data->addresses[0].addr) ||";
        print "        ether_addr_equal(addr, data->addresses[1].addr))";
        print "        return true;";
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
    /* deliver the frame to every hwsim radio on the same channel */' "$CFILE"
    echo "  - Comment before ack = ... added"
else
    echo "  - Comment before ack already present"
fi

if ! grep -q 'Forward an IEEE' "$CFILE"; then
    sed -i '/ack = mac80211_hwsim_tx_frame_no_nl/a \
    /* Forward an IEEE 802.11 ACK frame to the monitor as well */\n    if (ack)\n        mac80211_hwsim_monitor_ack(channel, hdr->addr2);\n' "$CFILE"
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
    {\    
/* Use distinct names to avoid shadowing existing locals */\
        struct mac80211_hwsim_data *poc = hw->priv;\
        struct ieee80211_hdr *poc_hdr = (struct ieee80211_hdr *)skb->data;\
        u16 fc = le16_to_cpu(poc_hdr->frame_control);\
        unsigned long now = jiffies;\
        /* Count auth frames per second */\
        if (ieee80211_is_auth(fc)) {\
                if (time_before(now, poc->poc_last_jiffies + HZ)) {\
                        poc->poc_auth_counter++;\
                } else {\
                        if (poc->poc_auth_counter > 20) {\
                                poc->poc_flood_streak++;\
                                poc->poc_quiet_streak = 0;\
                                pr_info("[HWSIM-POC][%s] Flood window (%d/5)\n",\
                                        wiphy_name(hw->wiphy), poc->poc_flood_streak);\
                        } else {\
                                if (poc->poc_attack_triggered)\
                                        poc->poc_quiet_streak++;\
                                else\
                                        poc->poc_quiet_streak = 0;\
                                poc->poc_flood_streak = 0;\
                        }\
                        if (poc->poc_flood_streak >= 5 && !poc->poc_attack_triggered) {\
                                poc->poc_attack_triggered = true;\
                                pr_info("[HWSIM-POC][%s] Flood 5s -> vuln mode ON\n",\
                                        wiphy_name(hw->wiphy));\
                        }\
                        if (poc->poc_attack_triggered && poc->poc_quiet_streak >= 10) {\
                                poc->poc_attack_triggered = false;\
                                pr_info("[HWSIM-POC][%s] Quiet 10s -> vuln mode RESET\n",\
                                        wiphy_name(hw->wiphy));\
                        }\
                        poc->poc_auth_counter = 1;\
                        poc->poc_last_jiffies = now;\
                }\
        }\
        /*\
         * Drop only after trigger\
         * IMPORTANT:\
         * - 802.11 header is not always 24 bytes\
         * - Need >= hdrlen + 8 before reading LLC/SNAP EtherType bytes 6..7\
         */\
        if (poc->poc_attack_triggered && ieee80211_is_data(fc)) {\
                int hdrlen = ieee80211_hdrlen(fc);\
                if (skb->len >= hdrlen + 8) {\
                        const u8 *llc = skb->data + hdrlen;\
                        /* EtherType in LLC/SNAP header bytes 6..7 */\
                        bool is_eapol = (llc[6] == 0x88 && llc[7] == 0x8e);\
                        if (!is_eapol) {\
                                pr_info("[HWSIM-POC][%s] Dropping data frame len=%u\n",\
                                        wiphy_name(hw->wiphy), skb->len);\
                                /*\
                                 * Choose the correct free call for the path you hooked:\
                                 * - TX path: ieee80211_free_txskb(hw, skb);\
                                 * - RX path: kfree_skb(skb); (or the function’s existing error-path free)\
                                 * FREE_SKB_PLACEHOLDER\
                                 */\
                                ieee80211_free_txskb(hw, skb);\
                                return;\
                        }\
                }\
        }\
    }' "$CFILE"
    echo "  - Dragondrain PoC per-interface monitor patch added"
else
    echo "  - Dragondrain PoC per-interface monitor patch already present"
fi

echo "mac80211_hwsim.c patched successfully"
