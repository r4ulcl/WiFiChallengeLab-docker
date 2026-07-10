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

# Per-branch cache so an offline rebuild can reuse previously fetched sources
# (raw, pre-patch) for the matching kernel branch.
CACHE_DIR="${DEST}/cache/${branch}"
mkdir -p "$CACHE_DIR"

printf "→ Kernel branch:  %s\n→ Source path:    %s\n" "$branch" "$subdir"

for f in "${files[@]}"; do
  url="${base_url}/${f}?h=${branch}"
  dst="${DEST}/${f}"
  cache="${CACHE_DIR}/${f}"
  if [[ -f "$dst" ]]; then
    echo "  • $f already exists – skipping download"
    continue
  fi
  printf '  • Downloading %s …\n' "$f"
  # Bounded timeouts so no network fails fast instead of hanging the container.
  if curl -fsSL --connect-timeout 5 --max-time 30 "$url" -o "$dst"; then
    cp -f "$dst" "$cache"        # refresh cache for offline reuse
  else
    rm -f "$dst"                 # drop any truncated/empty output
    if [[ -f "$cache" ]]; then
      echo "  • download failed – using cached $f for branch $branch"
      cp -f "$cache" "$dst"
    else
      echo "  ✖ download failed and no cached $f for branch $branch (offline?)" >&2
    fi
  fi
done
echo "✔ Sources are in ${DEST}"

CFILE="${DEST}/mac80211_hwsim.c"
[[ -f "$CFILE" ]] || { echo "✖ ${CFILE} not found – aborting" >&2; exit 1; }

# MODULE_VERSION
if ! grep -q 'WiFiChallengeLab-version' "$CFILE"; then
  perl -0777 -i -pe 's/MODULE_LICENSE\("GPL"\);\n/MODULE_LICENSE("GPL");\nMODULE_VERSION("2.5-WiFiChallengeLab-version");\n/s' "$CFILE"
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

# Client-less PMKID for the wifi-campus AP.
# The campus BSSID runs WPA2-PSK with NO real client on purpose. hcxdumptool
# associates from its own random client MAC, so the Assoc Resp + EAPOL msg 1
# (carrying the PMKID) that hostapd sends are addressed to a MAC no hwsim radio
# owns; mac80211_hwsim_tx_frame_no_nl() then reports the frame as un-ACKed and
# hostapd drops the STA before the PMKID goes out. Force ack=true for frames
# *sourced* from the campus BSSID so the association completes and the PMKID is
# captured client-lessly. Scoped to that BSSID only (keep in sync with
# MAC_ROAM1 in wlan_config) so every other AP keeps real ACK semantics.
if ! grep -q 'WiFiChallenge] Client-less PMKID campus ACK' "$CFILE"; then
  IFS= read -r -d '' PMKID_CAMPUS_ACK_BLOCK <<'EOF' || true
	/* [WiFiChallenge] Client-less PMKID campus ACK.
	 * The wifi-campus BSSID has no real client, so hostapd's Assoc Resp and
	 * EAPOL msg 1 (with the PMKID) are addressed to hcxdumptool's random client
	 * MAC that no hwsim radio owns and would never be ACKed. Force-ACK frames
	 * sourced from this BSSID so the association completes and the PMKID is
	 * captured client-lessly. One shared .ko serves both deploys, so BOTH BSSIDs
	 * are listed. Keep in sync with MAC_ROAM1 in wlan_config (dev) AND
	 * wlan_config_challenge (CTF). */
	if (!ack) {
		static const u8 wifichallenge_pmkid_bssids[][ETH_ALEN] = {
			/* wlan_config (dev/local) */
			{ 0xf0, 0x9f, 0xc2, 0x71, 0x22, 0x31 },
			/* wlan_config_challenge (CTF deploy) */
			{ 0xf0, 0x9f, 0xc2, 0x3c, 0xb1, 0x31 },
		};
		int wc_i;

		for (wc_i = 0; wc_i < ARRAY_SIZE(wifichallenge_pmkid_bssids); wc_i++) {
			if (ether_addr_equal(hdr->addr2,
					     wifichallenge_pmkid_bssids[wc_i])) {
				ack = true;
				break;
			}
		}
	}
EOF
  export PMKID_CAMPUS_ACK_BLOCK
  perl -0777 -i -pe '
    my $blk = $ENV{PMKID_CAMPUS_ACK_BLOCK};
    s/\n\treturn ack;\n\}/\n$blk\n\treturn ack;\n}/;
  ' "$CFILE"
  unset PMKID_CAMPUS_ACK_BLOCK
  echo "  • Client-less PMKID campus ACK block inserted"
else
  echo "  • Client-less PMKID campus ACK block already present"
fi

echo "✔ mac80211_hwsim.c patched successfully"
