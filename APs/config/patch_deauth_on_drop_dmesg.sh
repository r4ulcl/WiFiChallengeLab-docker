#!/usr/bin/env bash
set -euo pipefail

patch_CTRL_DIR_PREFIX="${1:-/run/hostapd-}"   # /run/hostapd-wlan30 etc
patch_COOLDOWN_SEC="${2:-5}"

patch_last_run=0
patch_now_epoch() { date +%s; }

patch_ifaces_for_phy() {
  local patch_phy="$1"
  iw dev 2>/dev/null | awk -v phy="${patch_phy#phy}" '
    $1 ~ /^phy#/ {cur = substr($1, 5)}
    $1 == "Interface" && cur == phy {print $2}
  '
}

patch_ctrl_dir_for_iface() {
  local patch_if="$1"
  local patch_dir="${patch_CTRL_DIR_PREFIX}${patch_if}"
  [[ -S "${patch_dir}/${patch_if}" ]] && { echo "$patch_dir"; return 0; }
  return 1
}

patch_get_stas() {
  local patch_if="$1"
  local patch_ctrl_dir="$2"

  # Preferred: list_sta (one MAC per line)
  local patch_macs
  patch_macs="$(hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" list_sta 2>/dev/null || true)"
  if [[ -n "$patch_macs" ]]; then
    printf "%s\n" "$patch_macs" | awk 'NF==1 {print $1}'
    return 0
  fi

  # Fallback: parse all_sta (MAC appears on its own line)
  hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" all_sta 2>/dev/null \
    | awk '/^([0-9a-f]{2}:){5}[0-9a-f]{2}$/ {print}'
}

patch_deauth_all_on_iface() {
  local patch_if="$1"
  local patch_ctrl_dir="$2"
  local patch_macs

  patch_macs="$(patch_get_stas "$patch_if" "$patch_ctrl_dir" || true)"
  if [[ -z "$patch_macs" ]]; then
    echo "[=] ${patch_if}: no stations (ctrl=${patch_ctrl_dir})" >&2
    return 0
  fi

  echo "[+] ${patch_if}: deauth stations (ctrl=${patch_ctrl_dir}):" >&2
  echo "$patch_macs" >&2

  while IFS= read -r patch_mac; do
    [[ -z "$patch_mac" ]] && continue
    hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" deauthenticate "$patch_mac" >/dev/null 2>&1 || true
  done <<< "$patch_macs"
}

sudo dmesg -wH | while IFS= read -r patch_line; do
  if [[ "$patch_line" =~ \[HWSIM-POC\]\[(phy[0-9]+)\]\ Dropping\ data\ frame ]]; then
    patch_phy="${BASH_REMATCH[1]}"

    patch_now="$(patch_now_epoch)"
    if (( patch_now - patch_last_run < patch_COOLDOWN_SEC )); then
      continue
    fi
    patch_last_run="$patch_now"

    mapfile -t patch_ifaces < <(patch_ifaces_for_phy "$patch_phy")
    [[ "${#patch_ifaces[@]}" -eq 0 ]] && continue

    for patch_if in "${patch_ifaces[@]}"; do
      # If you want only wlan30, uncomment:
      # [[ "$patch_if" == "wlan30" ]] || continue

      if patch_ctrl_dir="$(patch_ctrl_dir_for_iface "$patch_if")"; then
        patch_deauth_all_on_iface "$patch_if" "$patch_ctrl_dir"
      fi
    done
  fi
done
