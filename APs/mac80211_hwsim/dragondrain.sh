#!/bin/bash
#set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  bash dragondrain.sh [mac80211_hwsim.c]
  bash dragondrain.sh --file mac80211_hwsim.c [--simulate-dos|--detect-only]

Environment tuning (all optional):
  PATCH_AUTH_THRESHOLD        auth req/sec threshold (default: 30)
  PATCH_SAE_AUTH_THRESHOLD    SAE auth req/sec threshold (default: 8)
  PATCH_ASSOC_THRESHOLD       assoc+reassoc req/sec threshold (default: 20)
  PATCH_TOTAL_THRESHOLD       total auth+assoc req/sec threshold (default: 40)
  PATCH_DETECT_WINDOWS        consecutive flood windows before trigger (default: 3)
  PATCH_QUIET_WINDOWS         quiet windows before reset (default: 6)
  PATCH_BLOCK_SECONDS         DoS block duration when detected (default: 30)
  PATCH_SIMULATE_DOS          1 enables periodic simulated DoS (default: 0)
  PATCH_SIM_INTERVAL_SECONDS  interval between simulations (default: 90)
  PATCH_SIM_BLOCK_SECONDS     simulated DoS duration (default: 15)
EOF
}

require_posint() {
  local name="$1"
  local value="$2"
  if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]]; then
    echo "[-] $name must be a positive integer, got: $value" >&2
    exit 1
  fi
}

patch_FILE="mac80211_hwsim.c"
patch_FILE_SET=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      usage
      exit 0
      ;;
    --file)
      patch_FILE="${2:-}"
      if [[ -z "$patch_FILE" ]]; then
        echo "[-] --file requires a path" >&2
        exit 1
      fi
      patch_FILE_SET=1
      shift 2
      ;;
    --simulate-dos)
      PATCH_SIMULATE_DOS=1
      shift
      ;;
    --detect-only)
      PATCH_SIMULATE_DOS=0
      shift
      ;;
    *)
      if [[ "$patch_FILE_SET" -eq 0 && "$1" != --* ]]; then
        patch_FILE="$1"
        patch_FILE_SET=1
        shift
      else
        echo "[-] Unknown argument: $1" >&2
        usage
        exit 1
      fi
      ;;
  esac
done

PATCH_AUTH_THRESHOLD="${PATCH_AUTH_THRESHOLD:-30}"
PATCH_SAE_AUTH_THRESHOLD="${PATCH_SAE_AUTH_THRESHOLD:-8}"
PATCH_ASSOC_THRESHOLD="${PATCH_ASSOC_THRESHOLD:-20}"
PATCH_TOTAL_THRESHOLD="${PATCH_TOTAL_THRESHOLD:-40}"
PATCH_DETECT_WINDOWS="${PATCH_DETECT_WINDOWS:-3}"
PATCH_QUIET_WINDOWS="${PATCH_QUIET_WINDOWS:-6}"
PATCH_BLOCK_SECONDS="${PATCH_BLOCK_SECONDS:-30}"
PATCH_SIMULATE_DOS="${PATCH_SIMULATE_DOS:-0}"
PATCH_SIM_INTERVAL_SECONDS="${PATCH_SIM_INTERVAL_SECONDS:-90}"
PATCH_SIM_BLOCK_SECONDS="${PATCH_SIM_BLOCK_SECONDS:-15}"

require_posint PATCH_AUTH_THRESHOLD "$PATCH_AUTH_THRESHOLD"
require_posint PATCH_SAE_AUTH_THRESHOLD "$PATCH_SAE_AUTH_THRESHOLD"
require_posint PATCH_ASSOC_THRESHOLD "$PATCH_ASSOC_THRESHOLD"
require_posint PATCH_TOTAL_THRESHOLD "$PATCH_TOTAL_THRESHOLD"
require_posint PATCH_DETECT_WINDOWS "$PATCH_DETECT_WINDOWS"
require_posint PATCH_QUIET_WINDOWS "$PATCH_QUIET_WINDOWS"
require_posint PATCH_BLOCK_SECONDS "$PATCH_BLOCK_SECONDS"
require_posint PATCH_SIM_INTERVAL_SECONDS "$PATCH_SIM_INTERVAL_SECONDS"
require_posint PATCH_SIM_BLOCK_SECONDS "$PATCH_SIM_BLOCK_SECONDS"

if [[ "$PATCH_SIMULATE_DOS" != "0" && "$PATCH_SIMULATE_DOS" != "1" ]]; then
  echo "[-] PATCH_SIMULATE_DOS must be 0 or 1" >&2
  exit 1
fi

if [[ ! -f "$patch_FILE" ]]; then
  echo "[-] File not found: $patch_FILE" >&2
  exit 1
fi

cp -a "$patch_FILE" "$patch_FILE.bak"

patch_HELPERS_MARK="/* [HWSIM-PATCH] kick helpers */"
patch_APFILTER_MARK="/* [HWSIM-PATCH] ap dest filter */"
patch_RX_MARK_BEGIN="/* [HWSIM-PATCH-RX] begin */"

echo "[i] Tuning: auth=$PATCH_AUTH_THRESHOLD sae_auth=$PATCH_SAE_AUTH_THRESHOLD assoc=$PATCH_ASSOC_THRESHOLD total=$PATCH_TOTAL_THRESHOLD detect_windows=$PATCH_DETECT_WINDOWS quiet_windows=$PATCH_QUIET_WINDOWS block_s=$PATCH_BLOCK_SECONDS simulate_dos=$PATCH_SIMULATE_DOS sim_interval_s=$PATCH_SIM_INTERVAL_SECONDS sim_block_s=$PATCH_SIM_BLOCK_SECONDS"

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
\t/* Patch flood detection and DoS simulation */\
\tbool patch_attack_triggered;\
\tint patch_auth_counter;\
\tint patch_sae_auth_counter;\
\tint patch_assoc_counter;\
\tunsigned long patch_last_jiffies;\
\tint patch_flood_streak;\
\tint patch_quiet_streak;\
\tunsigned long patch_block_until_jiffies;\
\tunsigned long patch_simulate_next_jiffies;\
\tunsigned long patch_simulate_until_jiffies;\
' "$patch_FILE"
  echo "[+] Added patch_ fields to struct mac80211_hwsim_data"
else
  echo "[=] patch_ fields already present"
fi

# 3) Insert kick helpers if missing
if ! grep -qF "$patch_HELPERS_MARK" "$patch_FILE"; then
  patch_HELPERS_CONTENT=$(cat <<'PATCH_EOF'

/* [HWSIM-PATCH] kick helpers */
#ifndef WLAN_AUTH_SAE
#define WLAN_AUTH_SAE 3
#endif

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

# 5) RX wrapper (receiver-only flood detection + optional DoS simulation)
if grep -qF "$patch_RX_MARK_BEGIN" "$patch_FILE"; then
  echo "[=] RX wrapper already present"
else
  patch_RX_WRAPPER=$(cat <<PATCH_EOF
do {
	/* [HWSIM-PATCH-RX] begin */
	struct ieee80211_hw *patch_hw = data->hw;
	struct sk_buff *patch_skb = skb;
	struct mac80211_hwsim_data *patch_p = patch_hw->priv;
	struct ieee80211_hdr *patch_hdr;
	struct ieee80211_mgmt *patch_mgmt;
	u16 patch_fc;
	u16 patch_auth_alg = 0;
	unsigned long patch_now = jiffies;
	bool patch_mgmt_req;
	bool patch_is_sae_auth = false;
	bool patch_flood;
	int patch_total;
	bool patch_attack_active;
	bool patch_simulation_active;

	if (patch_skb && patch_skb->len >= 24) {
		patch_hdr = (struct ieee80211_hdr *)patch_skb->data;
		patch_mgmt = (struct ieee80211_mgmt *)patch_skb->data;
		patch_fc = le16_to_cpu(patch_hdr->frame_control);
		patch_mgmt_req = ieee80211_is_auth(patch_fc) ||
				 ieee80211_is_assoc_req(patch_fc) ||
				 ieee80211_is_reassoc_req(patch_fc);
		if (ieee80211_is_auth(patch_fc) && patch_skb->len >= 26) {
			patch_auth_alg = le16_to_cpu(patch_mgmt->u.auth.auth_alg);
			patch_is_sae_auth = patch_auth_alg == WLAN_AUTH_SAE;
		}

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

		if (${PATCH_SIMULATE_DOS}) {
			if (!patch_p->patch_simulate_next_jiffies)
				patch_p->patch_simulate_next_jiffies = patch_now + ${PATCH_SIM_INTERVAL_SECONDS} * HZ;

			if (time_after_eq(patch_now, patch_p->patch_simulate_next_jiffies)) {
				patch_p->patch_simulate_until_jiffies = patch_now + ${PATCH_SIM_BLOCK_SECONDS} * HZ;
				patch_p->patch_simulate_next_jiffies = patch_now + ${PATCH_SIM_INTERVAL_SECONDS} * HZ;

				if (!patch_kick_inited) {
					INIT_WORK(&patch_kick_work, patch_kick_workfn);
					patch_kick_inited = true;
				}
				patch_kick_hw = patch_hw;
				ieee80211_queue_work(patch_hw, &patch_kick_work);
				pr_info("[HWSIM-PATCH][%s] Simulated DoS for %ds\n",
					wiphy_name(patch_hw->wiphy), ${PATCH_SIM_BLOCK_SECONDS});
			}
		}

		patch_attack_active = patch_p->patch_attack_triggered &&
				     time_before(patch_now, patch_p->patch_block_until_jiffies);
		patch_simulation_active = ${PATCH_SIMULATE_DOS} &&
					 time_before(patch_now, patch_p->patch_simulate_until_jiffies);

		if ((patch_attack_active && patch_mgmt_req) ||
		    (patch_simulation_active && (patch_mgmt_req || ieee80211_is_data(patch_fc)))) {
			dev_kfree_skb_any(patch_skb);
			patch_skb = NULL;
		}

		if (patch_skb && patch_mgmt_req) {
			if (time_before(patch_now, patch_p->patch_last_jiffies + HZ)) {
				if (ieee80211_is_auth(patch_fc)) {
					patch_p->patch_auth_counter++;
					if (patch_is_sae_auth)
						patch_p->patch_sae_auth_counter++;
				} else {
					patch_p->patch_assoc_counter++;
				}
			} else {
				patch_total = patch_p->patch_auth_counter + patch_p->patch_assoc_counter;
				patch_flood = patch_p->patch_auth_counter >= ${PATCH_AUTH_THRESHOLD} ||
					     patch_p->patch_sae_auth_counter >= ${PATCH_SAE_AUTH_THRESHOLD} ||
					     patch_p->patch_assoc_counter >= ${PATCH_ASSOC_THRESHOLD} ||
					     patch_total >= ${PATCH_TOTAL_THRESHOLD};

				if (patch_flood) {
					patch_p->patch_flood_streak++;
					patch_p->patch_quiet_streak = 0;
					pr_info("[HWSIM-PATCH][%s] Flood window auth=%d sae_auth=%d assoc=%d total=%d (streak=%d/%d)\n",
						wiphy_name(patch_hw->wiphy),
						patch_p->patch_auth_counter,
						patch_p->patch_sae_auth_counter,
						patch_p->patch_assoc_counter,
						patch_total,
						patch_p->patch_flood_streak,
						${PATCH_DETECT_WINDOWS});
				} else {
					if (patch_p->patch_flood_streak > 0)
						patch_p->patch_flood_streak--;
					if (patch_p->patch_attack_triggered)
						patch_p->patch_quiet_streak++;
				}

				if (patch_p->patch_flood_streak >= ${PATCH_DETECT_WINDOWS} && !patch_attack_active) {
					patch_p->patch_attack_triggered = true;
					patch_p->patch_block_until_jiffies = patch_now + ${PATCH_BLOCK_SECONDS} * HZ;
					patch_p->patch_quiet_streak = 0;

					if (!patch_kick_inited) {
						INIT_WORK(&patch_kick_work, patch_kick_workfn);
						patch_kick_inited = true;
					}
					patch_kick_hw = patch_hw;
					ieee80211_queue_work(patch_hw, &patch_kick_work);
					pr_info("[HWSIM-PATCH][%s] DragonDrain detected -> DoS mode for %ds\n",
						wiphy_name(patch_hw->wiphy), ${PATCH_BLOCK_SECONDS});
				}

				if (patch_p->patch_attack_triggered &&
				    patch_p->patch_quiet_streak >= ${PATCH_QUIET_WINDOWS}) {
					patch_p->patch_attack_triggered = false;
					patch_p->patch_flood_streak = 0;
					patch_p->patch_quiet_streak = 0;
					patch_p->patch_sae_auth_counter = 0;
					pr_info("[HWSIM-PATCH][%s] Quiet windows reached -> reset detection state\n",
						wiphy_name(patch_hw->wiphy));
				}

				patch_p->patch_auth_counter = ieee80211_is_auth(patch_fc) ? 1 : 0;
				patch_p->patch_sae_auth_counter = (ieee80211_is_auth(patch_fc) && patch_is_sae_auth) ? 1 : 0;
				patch_p->patch_assoc_counter = ieee80211_is_auth(patch_fc) ? 0 : 1;
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
