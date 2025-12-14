#!/bin/bash
set -euo pipefail

patch_FILE="${1:-mac80211_hwsim.c}"

if [[ ! -f "$patch_FILE" ]]; then
  echo "[-] File not found: $patch_FILE" >&2
  exit 1
fi

cp -a "$patch_FILE" "$patch_FILE.bak"

patch_HELPERS_MARK="/* [HWSIM-PATCH] kick helpers */"
patch_APFILTER_MARK="/* [HWSIM-PATCH] ap dest filter */"
patch_RX_MARK_BEGIN="/* [HWSIM-PATCH-RX] begin */"

# 1) Ensure required headers
if ! grep -q '<linux/workqueue.h>' "$patch_FILE"; then
  perl -i -pe 'BEGIN{$patch_done=0} if(!$patch_done && /^#include\b/){ print "#include <linux/workqueue.h>\n"; $patch_done=1 }' "$patch_FILE"
  echo "[+] Added <linux/workqueue.h>"
else
  echo "[=] <linux/workqueue.h> already present"
fi

if ! grep -q '<linux/if_ether.h>' "$patch_FILE"; then
  perl -i -pe 'BEGIN{$patch_done=0} if(!$patch_done && /^#include\b/){ print "#include <linux/if_ether.h>\n"; $patch_done=1 }' "$patch_FILE"
  echo "[+] Added <linux/if_ether.h>"
else
  echo "[=] <linux/if_ether.h> already present"
fi

# 2) Add patch_ fields to struct mac80211_hwsim_data
if ! grep -q "patch_attack_triggered" "$patch_FILE"; then
  sed -i '/struct mac80211_hwsim_data[[:space:]]*{/a\
\t/* Patch flood detection (receiver only) */\
\tbool patch_attack_triggered;\
\tint patch_auth_counter;\
\tunsigned long patch_last_jiffies;\
\tint patch_flood_streak;\
\tint patch_quiet_streak;\
\tunsigned long patch_block_until_jiffies;\
' "$patch_FILE"
  echo "[+] Added patch_ fields to struct mac80211_hwsim_data"
else
  echo "[=] patch_ fields already present"
fi

# 3) Insert kick helpers if missing
if ! grep -qF "$patch_HELPERS_MARK" "$patch_FILE"; then
  patch_HELPERS_CONTENT=$(cat <<'PATCH_EOF'

/* [HWSIM-PATCH] kick helpers */
static struct work_struct patch_kick_work;
static struct ieee80211_hw *patch_kick_hw;
static bool patch_kick_inited;

static void patch_kick_workfn(struct work_struct *patch_work)
{
	if (patch_kick_hw)
		ieee80211_restart_hw(patch_kick_hw);
}

PATCH_EOF
)
  patch_INS="$patch_HELPERS_CONTENT" perl -0777 -i -pe '
    my $ins = $ENV{patch_INS};
    if (index($_, "/* [HWSIM-PATCH] kick helpers */") < 0) {
      s/((?:^[ \t]*#include[^\n]*\n)+)/$1$ins\n/m;
    }
  ' "$patch_FILE"
  echo "[+] Inserted patch_ kick helpers"
else
  echo "[=] patch_ kick helpers already present"
fi

# 4) Insert AP destination filter helpers
if ! grep -qF "$patch_APFILTER_MARK" "$patch_FILE"; then
  patch_APFILTER_CONTENT=$(cat <<'PATCH_EOF'
/* [HWSIM-PATCH] ap dest filter */
struct patch_ap_match_ctx {
	const u8 *patch_a1;
	const u8 *patch_a3;
	bool patch_match;
};

static void patch_ap_match_iter(void *patch_data, u8 *patch_mac,
				struct ieee80211_vif *patch_vif)
{
	struct patch_ap_match_ctx *patch_ctx = patch_data;

	if (patch_ctx->patch_match)
		return;

	/* Only AP and AP_VLAN */
	if (patch_vif->type != NL80211_IFTYPE_AP &&
	    patch_vif->type != NL80211_IFTYPE_AP_VLAN)
		return;

	/* Use patch_mac (active vif address), not only vif->addr */
	if (patch_ctx->patch_a1 && patch_mac &&
	    memcmp(patch_mac, patch_ctx->patch_a1, ETH_ALEN) == 0)
		patch_ctx->patch_match = true;

	if (!patch_ctx->patch_match && patch_ctx->patch_a3 && patch_mac &&
	    memcmp(patch_mac, patch_ctx->patch_a3, ETH_ALEN) == 0)
		patch_ctx->patch_match = true;

	/* Fallback to vif->addr if needed */
	if (!patch_ctx->patch_match && patch_ctx->patch_a1 &&
	    memcmp(patch_vif->addr, patch_ctx->patch_a1, ETH_ALEN) == 0)
		patch_ctx->patch_match = true;

	if (!patch_ctx->patch_match && patch_ctx->patch_a3 &&
	    memcmp(patch_vif->addr, patch_ctx->patch_a3, ETH_ALEN) == 0)
		patch_ctx->patch_match = true;
}

static bool patch_is_for_local_ap(struct ieee80211_hw *patch_hw,
				  const u8 *patch_a1, const u8 *patch_a3)
{
	struct patch_ap_match_ctx patch_ctx = {
		.patch_a1 = patch_a1,
		.patch_a3 = patch_a3,
		.patch_match = false,
	};
	u32 patch_iter_flags = 0;

#ifdef IEEE80211_IFACE_ITER_ACTIVE
	patch_iter_flags = IEEE80211_IFACE_ITER_ACTIVE;
#elif defined(IEEE80211_IFACE_ITER_NORMAL)
	patch_iter_flags = IEEE80211_IFACE_ITER_NORMAL;
#endif

	ieee80211_iterate_active_interfaces_atomic(patch_hw, patch_iter_flags,
						   patch_ap_match_iter, &patch_ctx);
	return patch_ctx.patch_match;
}
PATCH_EOF
)
  patch_INS="$patch_APFILTER_CONTENT" perl -0777 -i -pe '
    my $ins = $ENV{patch_INS};
    if (index($_, "/* [HWSIM-PATCH] ap dest filter */") < 0) {
      s{(/\* \[HWSIM-PATCH\] kick helpers \*/.*?\n\n)}{$1$ins\n}ms;
    }
  ' "$patch_FILE"
  echo "[+] Inserted patch_ AP destination filter helpers"
else
  echo "[=] patch_ AP destination filter helpers already present"
fi

# 5) RX wrapper (receiver-only flood detection)
if grep -qF "$patch_RX_MARK_BEGIN" "$patch_FILE"; then
  echo "[=] RX wrapper already present"
else
  patch_RX_WRAPPER=$(cat <<'PATCH_EOF'
do {
	/* [HWSIM-PATCH-RX] begin */
	struct ieee80211_hw *patch_hw = data->hw;
	struct sk_buff *patch_skb = skb;
	struct mac80211_hwsim_data *patch_p = patch_hw->priv;
	struct ieee80211_hdr *patch_hdr;
	u16 patch_fc;
	unsigned long patch_now = jiffies;

	if (patch_skb && patch_skb->len >= 2) {
		patch_hdr = (struct ieee80211_hdr *)patch_skb->data;
		patch_fc = le16_to_cpu(patch_hdr->frame_control);

		/* Receiver only:
		* If addr1 is broadcast/multicast, use addr3 (BSSID) to identify the AP.
		* If addr1 is unicast, match either addr1 or addr3 against the AP vif.
		*/
		if (is_multicast_ether_addr(patch_hdr->addr1)) {
			if (!patch_is_for_local_ap(patch_hw, NULL, patch_hdr->addr3))
				goto patch_pass;
		} else {
			if (!patch_is_for_local_ap(patch_hw, patch_hdr->addr1, patch_hdr->addr3))
				goto patch_pass;
		}
		if (patch_p->patch_attack_triggered &&
		    time_before(patch_now, patch_p->patch_block_until_jiffies)) {
			if (ieee80211_is_auth(patch_fc) ||
			    ieee80211_is_assoc_req(patch_fc) ||
			    ieee80211_is_reassoc_req(patch_fc)) {
				dev_kfree_skb_any(patch_skb);
				patch_skb = NULL;
			}
		}

		if (patch_skb && ieee80211_is_auth(patch_fc)) {
			if (time_before(patch_now, patch_p->patch_last_jiffies + HZ)) {
				patch_p->patch_auth_counter++;
			} else {
				if (patch_p->patch_auth_counter > 20) {
					patch_p->patch_flood_streak++;
					patch_p->patch_quiet_streak = 0;
					pr_info("[HWSIM-PATCH][%s] Flood window (%d/5)\n",
						wiphy_name(patch_hw->wiphy), patch_p->patch_flood_streak);
				} else {
					patch_p->patch_flood_streak = 0;
					if (patch_p->patch_attack_triggered)
						patch_p->patch_quiet_streak++;
					else
						patch_p->patch_quiet_streak = 0;
				}

				if (patch_p->patch_flood_streak >= 5 &&
				    !patch_p->patch_attack_triggered) {
					patch_p->patch_attack_triggered = true;
					patch_p->patch_block_until_jiffies = patch_now + 30 * HZ;

					pr_info("[HWSIM-PATCH][%s] Flood detected -> restarting hw to drop all stations\n",
						wiphy_name(patch_hw->wiphy));

					if (!patch_kick_inited) {
						INIT_WORK(&patch_kick_work, patch_kick_workfn);
						patch_kick_inited = true;
					}
					patch_kick_hw = patch_hw;
					ieee80211_queue_work(patch_hw, &patch_kick_work);
				}

				if (patch_p->patch_attack_triggered &&
				    patch_p->patch_quiet_streak >= 10) {
					patch_p->patch_attack_triggered = false;
					pr_info("[HWSIM-PATCH][%s] Quiet 10s -> mode RESET\n",
						wiphy_name(patch_hw->wiphy));
				}

				patch_p->patch_auth_counter = 1;
				patch_p->patch_last_jiffies = patch_now;
			}
		}
	}
	/* [HWSIM-PATCH-RX] end */

patch_pass:
	if (patch_skb)
		ieee80211_rx_irqsafe(patch_hw, patch_skb);
} while (0);
PATCH_EOF
)

  patch_TMP_PERL="$(mktemp)"
  cat >"$patch_TMP_PERL" <<'PERL_EOF'
use strict;
use warnings;
my $file = $ARGV[0];
local $/;
open my $fh, "<", $file or die "open: $!";
my $s = <$fh>;
close $fh;
die "already wrapped\n" if index($s, "/* [HWSIM-PATCH-RX] begin */") >= 0;
my $wrap = $ENV{patch_WRAPPER};
my $re = qr/^[ \t]*ieee80211_rx_irqsafe\(\s*data->hw\s*,\s*skb\s*\)\s*;\s*$/m;
if ($s !~ $re) { die "rx_irqsafe(data->hw, skb) call not found\n"; }
$s =~ s{$re}{$wrap}m;
open my $outf, ">", $file or die "write: $!";
print $outf $s;
close $outf;
PERL_EOF

  patch_WRAPPER="$patch_RX_WRAPPER" perl "$patch_TMP_PERL" "$patch_FILE" || {
    rm -f "$patch_TMP_PERL"
    echo "[-] Failed to wrap ieee80211_rx_irqsafe(data->hw, skb)" >&2
    exit 1
  }
  rm -f "$patch_TMP_PERL"
  echo "[+] Wrapped ieee80211_rx_irqsafe(data->hw, skb) inside RX path"
fi

echo "[+] Done. Backup at $patch_FILE.bak"
