#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./patch_deauth_on_drop_dmesg.sh [CTRL_DIR_PREFIX] [COOLDOWN_SEC]
# Example:
#   ./patch_deauth_on_drop_dmesg.sh /run/hostapd- 5
#
# With /run/hostapd-wlan30, CTRL_DIR_PREFIX should be: /run/hostapd-

patch_CTRL_DIR_PREFIX="${1:-/run/hostapd-}"
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
  if [[ -S "${patch_dir}/${patch_if}" ]]; then
    echo "$patch_dir"
    return 0
  fi
  if [[ -d "$patch_dir" ]]; then
    # Some setups place the socket directly in the dir under the interface name
    if [[ -S "${patch_dir}/${patch_if}" ]]; then
      echo "$patch_dir"
      return 0
    fi
  fi
  return 1
}

patch_deauth_all_on_iface() {
  local patch_if="$1"
  local patch_ctrl_dir="$2"
  local patch_out patch_macs

  patch_out="$(hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" all_sta 2>/dev/null || true)"
  patch_macs="$(printf "%s\n" "$patch_out" | awk '/^STA /{print $2}')"

  if [[ -z "$patch_macs" ]]; then
    echo "[=] ${patch_if}: no stations according to hostapd (ctrl=${patch_ctrl_dir})" >&2
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
  # Trigger on: [HWSIM-POC][phy213] Dropping data frame ...
  if [[ "$patch_line" =~ \[HWSIM-POC\]\[(phy[0-9]+)\]\ Dropping\ data\ frame ]]; then
    patch_phy="${BASH_REMATCH[1]}"

    patch_now="$(patch_now_epoch)"
    if (( patch_now - patch_last_run < patch_COOLDOWN_SEC )); then
      continue
    fi
    patch_last_run="$patch_now"

    mapfile -t patch_ifaces < <(patch_ifaces_for_phy "$patch_phy")
    if [[ "${#patch_ifaces[@]}" -eq 0 ]]; then
      echo "[!] Trigger on ${patch_phy} but no interfaces found via iw dev" >&2
      continue
    fi

    echo "[+] Trigger on ${patch_phy}. Candidate ifaces: ${patch_ifaces[*]}" >&2

    for patch_if in "${patch_ifaces[@]}"; do
      if patch_ctrl_dir="$(patch_ctrl_dir_for_iface "$patch_if")"; then
        patch_deauth_all_on_iface "$patch_if" "$patch_ctrl_dir"
      else
        echo "[=] ${patch_if}: no control socket at ${patch_CTRL_DIR_PREFIX}${patch_if}/${patch_if}" >&2
      fi
    done
  fi
done
