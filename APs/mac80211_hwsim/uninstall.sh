#!/usr/bin/env bash
set -euo pipefail

ALT_MODNAME="mac80211_hwsim_WiFiChallenge"
STOCK_MODNAME="mac80211_hwsim"
TARGET_VERSION="2.4.1-WiFiChallengeLab-version"

RELOAD_STOCK=1
REMOVE_ANY_VERSION=0

usage() {
  cat <<'EOF'
Usage:
  sudo bash uninstall.sh [--no-reload-stock] [--remove-any-version]

Options:
  --no-reload-stock     Do not load stock mac80211_hwsim after removal
  --remove-any-version  Remove the custom module file even if version != 2.4.1
  -h, --help            Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-reload-stock)
      RELOAD_STOCK=0
      ;;
    --remove-any-version)
      REMOVE_ANY_VERSION=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "[-] Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

if [[ "${EUID}" -ne 0 ]]; then
  echo "[-] Run as root (use sudo)." >&2
  exit 1
fi

KVER="$(uname -r)"
DEST_DIR="/lib/modules/${KVER}/kernel/drivers/net/wireless"
ALT_MOD_PATH="${DEST_DIR}/${ALT_MODNAME}.ko"
DKMS_MOD_PATH="/lib/modules/${KVER}/updates/dkms/${ALT_MODNAME}.ko"

echo "[*] Unloading ${ALT_MODNAME} if loaded..."
modprobe -r "${ALT_MODNAME}" 2>/dev/null || true

declare -a CANDIDATE_PATHS=(
  "${ALT_MOD_PATH}"
  "${DKMS_MOD_PATH}"
)

if RESOLVED_PATH="$(modinfo -n "${ALT_MODNAME}" 2>/dev/null)"; then
  if [[ -n "${RESOLVED_PATH}" && "${RESOLVED_PATH}" != "(builtin)" ]]; then
    CANDIDATE_PATHS+=("${RESOLVED_PATH}")
  fi
fi

declare -A SEEN=()
REMOVED=0
SKIPPED=0

for MOD_PATH in "${CANDIDATE_PATHS[@]}"; do
  [[ -n "${MOD_PATH}" ]] || continue
  [[ -f "${MOD_PATH}" ]] || continue

  if [[ -n "${SEEN[${MOD_PATH}]:-}" ]]; then
    continue
  fi
  SEEN["${MOD_PATH}"]=1

  MOD_VER="$(modinfo -F version "${MOD_PATH}" 2>/dev/null || true)"

  if [[ "${REMOVE_ANY_VERSION}" -eq 1 || "${MOD_VER}" == "${TARGET_VERSION}" ]]; then
    rm -f "${MOD_PATH}"
    echo "[+] Removed ${MOD_PATH} (version: ${MOD_VER:-unknown})"
    ((REMOVED+=1))
  else
    echo "[=] Keeping ${MOD_PATH} (version: ${MOD_VER:-unknown})"
    ((SKIPPED+=1))
  fi
done

if [[ "${REMOVED}" -gt 0 ]]; then
  echo "[*] Running depmod..."
  depmod -a
else
  echo "[=] No module files removed."
fi

if [[ "${RELOAD_STOCK}" -eq 1 ]]; then
  echo "[*] Loading stock ${STOCK_MODNAME}..."
  if modprobe "${STOCK_MODNAME}" 2>/dev/null; then
    echo "[+] Loaded ${STOCK_MODNAME}"
  else
    echo "[!] Could not load ${STOCK_MODNAME}. You can load it manually later."
  fi
fi

echo "[+] Done. removed=${REMOVED} skipped=${SKIPPED}"
