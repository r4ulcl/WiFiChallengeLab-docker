#!/usr/bin/env bash
set -euo pipefail

# Load WLAN definitions
WLAN_CONFIG_FILE="/root/wlan_config"

if [[ -r "$WLAN_CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$WLAN_CONFIG_FILE"
else
  echo "[!] Cannot read $WLAN_CONFIG_FILE" >&2
  exit 1
fi

# Validate required variables
: "${WLAN_DOWNGRADE:?WLAN_DOWNGRADE not set in /root/wlan_config}"
: "${WLAN_BRUTEFORCE:?WLAN_BRUTEFORCE not set in /root/wlan_config}"
: "${WLAN_6GHZ:?WLAN_6GHZ not set in /root/wlan_config}"
: "${WLAN_OWE:?WLAN_OWE not set in /root/wlan_config}"

patch_CTRL_DIR_PREFIX="${1:-/run/hostapd-}"
patch_COOLDOWN_SEC="${2:-5}"
patch_WINDOW_THRESHOLD="${3:-5}"

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

  local patch_try1="${patch_CTRL_DIR_PREFIX}${patch_if}"
  local patch_try2="/run/hostapd"
  local patch_try3="/var/run/hostapd"
  local patch_try4="/run/hostapd-${patch_if}"

  if [[ -S "${patch_try1}/${patch_if}" ]]; then echo "$patch_try1"; return 0; fi
  if [[ -S "${patch_try2}/${patch_if}" ]]; then echo "$patch_try2"; return 0; fi
  if [[ -S "${patch_try3}/${patch_if}" ]]; then echo "$patch_try3"; return 0; fi
  if [[ -S "${patch_try4}/${patch_if}" ]]; then echo "$patch_try4"; return 0; fi

  return 1
}

patch_get_stas_hostapd_all_sta() {
  local patch_if="$1"
  local patch_ctrl_dir="$2"

  hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" all_sta 2>/dev/null \
    | awk 'NF==1 && $0 ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/ { print $0 }'
}

patch_deauth_all_on_iface() {
  local patch_if="$1"
  local patch_ctrl_dir="${2:-}"

  echo "[*] Target iface=${patch_if} ctrl=${patch_ctrl_dir:-none}" >&2

  if [[ -z "${patch_ctrl_dir}" ]]; then
    echo "[!] ${patch_if}: no hostapd ctrl socket, cannot deauth via hostapd_cli" >&2
    return 0
  fi

  local patch_macs
  patch_macs="$(patch_get_stas_hostapd_all_sta "$patch_if" "$patch_ctrl_dir" || true)"

  # Fallback if all_sta yields nothing
  if [[ -z "$patch_macs" ]]; then
    patch_macs="$(hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" list_sta 2>/dev/null || true)"
    patch_macs="$(printf "%s\n" "$patch_macs" \
      | awk 'NF==1 && $1 ~ /^([0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$/ {print $1}')"
  fi

  if [[ -z "$patch_macs" ]]; then
    echo "[!] ${patch_if}: no stations reported by hostapd" >&2
    return 0
  fi

  echo "[+] ${patch_if}: deauth all stations:" >&2
  echo "$patch_macs" >&2

  while IFS= read -r patch_mac; do
    [[ -z "$patch_mac" ]] && continue
    hostapd_cli -p "$patch_ctrl_dir" -i "$patch_if" deauthenticate "$patch_mac" >/dev/null 2>&1 || true
  done <<< "$patch_macs"
}

# Return 0 (true) if any interface for this phy matches WLAN1/2/3
patch_phy_is_target() {
  local patch_phy="$1"
  local patch_if
  while IFS= read -r patch_if; do
    [[ -z "$patch_if" ]] && continue
    if [[ "$patch_if" == "$WLAN_DOWNGRADE" || "$patch_if" == "$WLAN_BRUTEFORCE" || "$patch_if" == "$WLAN_6GHZ"|| "$patch_if" == "$WLAN_OWE" ]]; then
      return 0
    fi
  done < <(patch_ifaces_for_phy "$patch_phy")
  return 1
}

sudo dmesg -wH | while IFS= read -r patch_line; do
  if [[ "$patch_line" =~ \[HWSIM-PATCH\]\[(phy[0-9]+)\]\ Flood\ window\ \(([0-9]+)/([0-9]+)\) ]]; then
    patch_phy="${BASH_REMATCH[1]}"
    patch_window="${BASH_REMATCH[2]}"
    patch_total="${BASH_REMATCH[3]}"

    # Only act if the phy corresponds to WLAN1/2/3 (via iw dev mapping)
    if ! patch_phy_is_target "$patch_phy"; then
      continue
    fi

    if (( patch_window <= patch_WINDOW_THRESHOLD )); then
      continue
    fi

    patch_now="$(patch_now_epoch)"
    if (( patch_now - patch_last_run < patch_COOLDOWN_SEC )); then
      continue
    fi
    patch_last_run="$patch_now"

    echo "[!] Detected flood on ${patch_phy}: window=${patch_window}/${patch_total} (threshold>${patch_WINDOW_THRESHOLD})" >&2

    mapfile -t patch_ifaces < <(patch_ifaces_for_phy "$patch_phy")
    if [[ "${#patch_ifaces[@]}" -eq 0 ]]; then
      echo "[!] No interfaces found for ${patch_phy} via iw dev" >&2
      continue
    fi

    # Only deauth on the interfaces you explicitly allow
    for patch_if in "${patch_ifaces[@]}"; do
      if [[ "$patch_if" != "$WLAN_DOWNGRADE" && "$patch_if" != "$WLAN_BRUTEFORCE" && "$patch_if" != "$WLAN_6GHZ" && "$patch_if" != "$WLAN_OWE" ]]; then
        continue
      fi

      patch_ctrl_dir=""
      if patch_ctrl_dir="$(patch_ctrl_dir_for_iface "$patch_if")"; then
        echo "[*] ${patch_if}: ctrl socket dir = ${patch_ctrl_dir}" >&2
      else
        echo "[!] ${patch_if}: no hostapd ctrl socket found in common paths" >&2
      fi

      patch_deauth_all_on_iface "$patch_if" "${patch_ctrl_dir:-}"
    done
  fi
done
