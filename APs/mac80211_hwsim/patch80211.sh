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
#
# Idempotent: if you run it twice it won’t duplicate the edits.
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

printf "→ Kernel branch:  %s\n→ Source path:    %s\n" "$branch" "$subdir"

# 2. Download the two source files (only if not already present)
for f in "${files[@]}"; do
    url="${base_url}/${f}?h=${branch}"
    dst="${DEST}/${f}"
    if [[ -f "$dst" ]]; then
        echo "  • $f already exists – skipping download"
        continue
    fi
    printf '  • Downloading %s …\n' "$f"
    curl -fsSL "$url" -o "$dst"
done
echo "✔ Sources are in ${DEST}"

# 3. Patch mac80211_hwsim.c
CFILE="${DEST}/mac80211_hwsim.c"
[[ -f "$CFILE" ]] || { echo "✖ ${CFILE} not found – aborting" >&2; exit 1; }

# 3-A  MODULE_VERSION ---------------------------------------------------
if ! grep -q 'WiFiChallengeLab-version' "$CFILE"; then
    sed -i '/MODULE_LICENSE("GPL");/a MODULE_VERSION("1.0-WiFiChallengeLab-version");' "$CFILE"
    echo "  • MODULE_VERSION added"
else
    echo "  • MODULE_VERSION already present"
fi

# 3-B  Rewrite hwsim_mon_xmit() ----------------------------------------
if ! grep -q 'mac80211_hwsim_tx_frame(data->hw' "$CFILE"; then
    # Replace from function header down to the first closing brace.
    sed -i -n ':a;N;$!ba;s#static netdev_tx_t hwsim_mon_xmit[^}]*}#static netdev_tx_t hwsim_mon_xmit(struct sk_buff *skb,\n\t\t\t\t\tstruct net_device *dev)\n{\n\tstruct mac80211_hwsim_data *data = netdev_priv(dev);\n\t/* fall back to the normal mac80211 transmit routine */\n\tmac80211_hwsim_tx_frame(data->hw, skb, data->channel);\n\treturn NETDEV_TX_OK;\n}#g' "$CFILE"
    echo "  • hwsim_mon_xmit() replaced"
else
    echo "  • hwsim_mon_xmit() already patched"
fi

# 3-C  Early ACK check in addr_match() ----------------------------------
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
    echo "  • Early ACK-match code inserted"
else
    echo "  • addr_match() already patched"
fi

# 3-D  Extra monitor-ACK handling in TX path ---------------------------
if ! grep -q 'deliver the frame to every hwsim radio' "$CFILE"; then
    sed -i '/data->tx_bytes += skb->len;/a \
\t/* deliver the frame to every hwsim radio on the same channel */' "$CFILE"
    echo "  • Comment before ack = … added"
fi

if ! grep -q 'Forward an IEEE' "$CFILE"; then
    sed -i '/ack = mac80211_hwsim_tx_frame_no_nl/a \
\t/* Forward an IEEE 802.11 ACK frame to the monitor as well */\n\tif (ack)\n\t\tmac80211_hwsim_monitor_ack(channel, hdr->addr2);\n' "$CFILE"
    echo "  • Extra monitor-ACK block inserted"
fi

echo "✔ mac80211_hwsim.c patched successfully"
                                                  