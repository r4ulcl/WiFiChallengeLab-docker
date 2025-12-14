#!/bin/bash
set -euo pipefail

patch_FILE="${1:-mac80211_hwsim.c}"

if [[ ! -f "$patch_FILE" ]]; then
  echo "[-] File not found: $patch_FILE" >&2
  exit 1
fi

cp -a "$patch_FILE" "$patch_FILE.bak"

patch_MARK_BEGIN="/* [HWSIM-PATCH] begin */"
patch_MARK_END="/* [HWSIM-PATCH] end */"
patch_HELPERS_MARK="/* [HWSIM-PATCH] kick helpers */"

# 0) Remove old POC block if present (leave old struct fields alone)
if grep -q "\[HWSIM-POC\] begin" "$patch_FILE"; then
  perl -0777 -i -pe 's@/\*\s*\[HWSIM-POC\]\s*begin\s*\*/.*?/\*\s*\[HWSIM-POC\]\s*end\s*\*/\s*@@gs' "$patch_FILE"
  echo "[+] Removed old HWSIM-POC block"
else
  echo "[=] No old HWSIM-POC block found"
fi

# 1) Ensure <linux/workqueue.h> exists (robust insertion)
if ! grep -q '<linux/workqueue.h>' "$patch_FILE"; then
  perl -i -pe 'BEGIN{$patch_done=0} if(!$patch_done && /^#include\b/){ print "#include <linux/workqueue.h>\n"; $patch_done=1 }' "$patch_FILE"
  echo "[+] Added <linux/workqueue.h>"
else
  echo "[=] <linux/workqueue.h> already present"
fi

# 2) Insert global kick helpers once (no container_of, no struct dependency)
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

# 3) Extend struct mac80211_hwsim_data with patch_ fields (idempotent)
if ! grep -q "patch_attack_triggered" "$patch_FILE"; then
  sed -i '/struct mac80211_hwsim_data[[:space:]]*{/a\
\t/* Patch flood detection (per interface) */\
\tbool patch_attack_triggered;\
\tint patch_auth_counter;\
\tunsigned long patch_last_jiffies;\
\tint patch_flood_streak;\
\tint patch_quiet_streak;\
' "$patch_FILE"
  echo "[+] Added patch_ fields to struct mac80211_hwsim_data"
else
  echo "[=] patch_ fields already present"
fi

# 4) Insert detection + kick logic once, after monitor_rx call
if grep -qF "$patch_MARK_BEGIN" "$patch_FILE"; then
  echo "[=] Patch logic already present"
else
  patch_BLOCK=$(cat <<'PATCH_EOF'
/* [HWSIM-PATCH] begin */
{
	struct mac80211_hwsim_data *patch_p = hw->priv;
	struct ieee80211_hdr *patch_hdr = (struct ieee80211_hdr *)skb->data;
	u16 patch_fc = le16_to_cpu(patch_hdr->frame_control);
	unsigned long patch_now = jiffies;

	/* Count auth frames per second */
	if (ieee80211_is_auth(patch_fc)) {
		if (time_before(patch_now, patch_p->patch_last_jiffies + HZ)) {
			patch_p->patch_auth_counter++;
		} else {
			if (patch_p->patch_auth_counter > 20) {
				patch_p->patch_flood_streak++;
				patch_p->patch_quiet_streak = 0;
				pr_info("[HWSIM-PATCH][%s] Flood window (%d/5)\n",
					wiphy_name(hw->wiphy), patch_p->patch_flood_streak);
			} else {
				if (patch_p->patch_attack_triggered)
					patch_p->patch_quiet_streak++;
				else
					patch_p->patch_quiet_streak = 0;
				patch_p->patch_flood_streak = 0;
			}

			if (patch_p->patch_flood_streak >= 5 && !patch_p->patch_attack_triggered) {
				patch_p->patch_attack_triggered = true;

				pr_info("[HWSIM-PATCH][%s] Flood detected -> restarting hw to drop all stations\n",
					wiphy_name(hw->wiphy));

				/* Kick all clients: restart mac80211 in work context */
				if (!patch_kick_inited) {
					INIT_WORK(&patch_kick_work, patch_kick_workfn);
					patch_kick_inited = true;
				}
				patch_kick_hw = hw;
				ieee80211_queue_work(hw, &patch_kick_work);
			}

			if (patch_p->patch_attack_triggered && patch_p->patch_quiet_streak >= 10) {
				patch_p->patch_attack_triggered = false;
				pr_info("[HWSIM-PATCH][%s] Quiet 10s -> mode RESET\n",
					wiphy_name(hw->wiphy));
			}

			patch_p->patch_auth_counter = 1;
			patch_p->patch_last_jiffies = patch_now;
		}
	}
}
/* [HWSIM-PATCH] end */
PATCH_EOF
)

  patch_INS="$patch_BLOCK" perl -0777 -i -pe '
    my $ins = $ENV{patch_INS};
    if (index($_, "/* [HWSIM-PATCH] begin */") < 0) {
      s/(mac80211_hwsim_monitor_rx\(\s*hw\s*,\s*skb\s*,\s*channel\s*\)\s*;\s*\n)/$1$ins\n/s;
    }
  ' "$patch_FILE"

  if grep -qF "$patch_MARK_BEGIN" "$patch_FILE"; then
    echo "[+] Inserted patch logic block (kick on flood)"
  else
    echo "[-] Could not find insertion point: mac80211_hwsim_monitor_rx(hw, skb, channel);" >&2
    exit 1
  fi
fi

echo "[+] Done. Backup at $patch_FILE.bak"
