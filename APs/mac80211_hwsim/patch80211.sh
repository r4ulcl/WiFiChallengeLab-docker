#!/usr/bin/env bash
#set -euo pipefail

DEST="./"
mkdir -p "$DEST"

kernel_full=$(uname -r)
IFS=. read -r kmaj kmin _ <<< "$kernel_full"
branch="linux-${kmaj}.${kmin}.y"

if (( kmaj > 6 || (kmaj == 6 && kmin >= 4) )); then
  subdir="drivers/net/wireless/virtual"
else
  subdir="drivers/net/wireless"
fi

base_url="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git/plain/${subdir}"
files=(mac80211_hwsim.c mac80211_hwsim.h)

printf "→ Kernel branch:  %s\n→ Source path:    %s\n" "$branch" "$subdir"

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

CFILE="${DEST}/mac80211_hwsim.c"
[[ -f "$CFILE" ]] || { echo "✖ ${CFILE} not found – aborting" >&2; exit 1; }

# MODULE_VERSION
if ! grep -q 'WiFiChallengeLab-version' "$CFILE"; then
  perl -0777 -i -pe 's/MODULE_LICENSE\("GPL"\);\n/MODULE_LICENSE("GPL");\nMODULE_VERSION("2.4.1-WiFiChallengeLab-version");\n/s' "$CFILE"
  echo "  • MODULE_VERSION added"
else
  echo "  • MODULE_VERSION already present"
fi

# Rewrite hwsim_mon_xmit()
if ! grep -q 'mac80211_hwsim_tx_frame(data->hw, skb, data->channel);' "$CFILE"; then
  perl -0777 -i -pe '
    s/static\s+netdev_tx_t\s+hwsim_mon_xmit\s*\([^)]*\)\s*\{.*?\n\}/static netdev_tx_t hwsim_mon_xmit(struct sk_buff *skb,\n\t\t\t\t\tstruct net_device *dev)\n{\n\tstruct mac80211_hwsim_data *data = netdev_priv(dev);\n\tmac80211_hwsim_tx_frame(data->hw, skb, data->channel);\n\treturn NETDEV_TX_OK;\n}/s
  ' "$CFILE"
  echo "  • hwsim_mon_xmit() replaced"
else
  echo "  • hwsim_mon_xmit() already patched"
fi

# Early ACK check in mac80211_hwsim_addr_match()
if ! grep -q 'ACK if destination is our permanent MAC' "$CFILE"; then
  perl -0777 -i -pe '
    s/(static\s+bool\s+mac80211_hwsim_addr_match[^{]*\{\n)/
$1\t\/\* ACK if destination is our permanent MAC (even with only monitor IFs). \*\/\n\tif (ether_addr_equal(addr, data->addresses[0].addr) ||\n\t    ether_addr_equal(addr, data->addresses[1].addr)) {\n\t\treturn true;\n\t}\n/s
  ' "$CFILE"
  echo "  • Early ACK-match code inserted"
else
  echo "  • addr_match() already patched"
fi

# Extra monitor-ACK handling in TX path
if ! grep -q 'deliver the frame to every hwsim radio on the same channel' "$CFILE"; then
  perl -0777 -i -pe '
    s/(data->tx_bytes\s*\+=\s*skb->len;\n)/$1\t\/\* deliver the frame to every hwsim radio on the same channel \*\/\n/s
  ' "$CFILE"
  echo "  • Comment before delivery added"
fi

if ! grep -q '\[WiFiChallenge\] Forward an IEEE 802\.11 ACK frame' "$CFILE"; then
  perl -0777 -i -pe '
    s/(ack\s*=\s*mac80211_hwsim_tx_frame_no_nl[^\n]*\n)/
$1\t\/\* [WiFiChallenge] Forward an IEEE 802.11 ACK frame to the monitor as well \*\/\n\tif (ack) {\n\t\tmac80211_hwsim_monitor_ack(channel, hdr->addr2);\n\t}\n/s
  ' "$CFILE"
  echo "  • Extra monitor-ACK block inserted"
else
  echo "  • Extra monitor-ACK block already present"
fi

echo "✔ mac80211_hwsim.c patched successfully"
