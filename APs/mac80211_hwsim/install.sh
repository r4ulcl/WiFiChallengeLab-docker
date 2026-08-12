#!/usr/bin/env bash
#
# install_hwsim.sh – build a side‑by‑side mac80211_hwsim with a
#                    fixed target version.
#
# set -euo pipefail

export DEBIAN_FRONTEND="${DEBIAN_FRONTEND:-noninteractive}"
export DEBCONF_NONINTERACTIVE_SEEN="${DEBCONF_NONINTERACTIVE_SEEN:-true}"
export DEBCONF_NOWARNINGS="${DEBCONF_NOWARNINGS:-yes}"
export DEBIAN_PRIORITY="${DEBIAN_PRIORITY:-critical}"
export NEEDRESTART_MODE="${NEEDRESTART_MODE:-a}"
export UCF_FORCE_CONFFNEW="${UCF_FORCE_CONFFNEW:-1}"
export APT_LISTCHANGES_FRONTEND="${APT_LISTCHANGES_FRONTEND:-none}"

### ---- configuration -------------------------------------------------
ALT_MODNAME="mac80211_hwsim_WiFiChallenge"
STOCK_MODNAME="mac80211_hwsim"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-0}"
HOST_USR_LIB_MOUNT="${HOST_USR_LIB_MOUNT:-/host_usr_lib}"
# Version stamped into the patched module by patch80211.sh (single source of truth).
TARGET_VERSION="2.5-WiFiChallengeLab-version"
# ----------------------------------------------------------------------

### ---- Fast path: already installed? -------------------------------
# Run this BEFORE any apt/curl/build step so an already-built module starts
# the lab fully offline (no internet required at AP container start).
KVER="$(uname -r)"
ALT_MOD_PATH_EARLY="/lib/modules/${KVER}/kernel/drivers/net/wireless/${ALT_MODNAME}.ko"
if [[ "$(modinfo -F version "${ALT_MOD_PATH_EARLY}" 2>/dev/null || echo none)" == "${TARGET_VERSION}" ]]; then
    echo "==> ${ALT_MODNAME} ${TARGET_VERSION} already installed for ${KVER}; nothing to do (offline-safe)."
    exit 0
fi
# ----------------------------------------------------------------------

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

apt_noninteractive() {
    run_as_root env \
        DEBIAN_FRONTEND="${DEBIAN_FRONTEND}" \
        DEBCONF_NONINTERACTIVE_SEEN="${DEBCONF_NONINTERACTIVE_SEEN}" \
        DEBCONF_NOWARNINGS="${DEBCONF_NOWARNINGS}" \
        DEBIAN_PRIORITY="${DEBIAN_PRIORITY}" \
        NEEDRESTART_MODE="${NEEDRESTART_MODE}" \
        UCF_FORCE_CONFFNEW="${UCF_FORCE_CONFFNEW}" \
        APT_LISTCHANGES_FRONTEND="${APT_LISTCHANGES_FRONTEND}" \
        apt-get -o Dpkg::Use-Pty=0 "$@" </dev/null
}

require_cmds=()
for c in make gcc g++; do
    command -v "${c}" >/dev/null 2>&1 || require_cmds+=("${c}")
done

if (( ${#require_cmds[@]} > 0 )); then
    if [[ "${AUTO_INSTALL_DEPS}" == "1" ]]; then
        echo "[i] Missing build tools (${require_cmds[*]}). Installing ..."
        apt_noninteractive install -y gcc g++ build-essential
    else
        echo "ERROR: Missing build tools: ${require_cmds[*]}"
        echo "Install them manually or run with AUTO_INSTALL_DEPS=1."
        exit 1
    fi
fi

KVER="$(uname -r)"
KBUILD_DIR="/lib/modules/${KVER}/build"
ALT_KBUILD_DIR="/usr/src/linux-headers-${KVER}"

has_kbuild_tree() {
    local dir="$1"
    [[ -n "${dir}" && -d "${dir}" && -f "${dir}/Makefile" && -f "${dir}/scripts/Kbuild.include" ]]
}

can_write_usr_src() {
    local probe="/usr/src/.wifichallenge_write_test_$$"
    if ( : > "${probe}" ) 2>/dev/null; then
        rm -f "${probe}" || true
        return 0
    fi
    return 1
}

can_write_usr_lib() {
    local probe="/usr/lib/.wifichallenge_write_test_$$"
    if ( : > "${probe}" ) 2>/dev/null; then
        rm -f "${probe}" || true
        return 0
    fi
    return 1
}

pkg_available() {
    apt-cache show "$1" >/dev/null 2>&1
}

restore_kbuild_from_host_mount() {
    local kbuild_ver host_kbuild_dir local_kbuild_dir
    kbuild_ver="$(echo "${KVER}" | cut -d. -f1,2)"
    host_kbuild_dir="${HOST_USR_LIB_MOUNT}/linux-kbuild-${kbuild_ver}"
    local_kbuild_dir="/usr/lib/linux-kbuild-${kbuild_ver}"

    if [[ ! -d "${host_kbuild_dir}/scripts" ]]; then
        return 0
    fi
    if [[ -f "${local_kbuild_dir}/scripts/Kbuild.include" ]]; then
        return 0
    fi
    if ! can_write_usr_lib; then
        echo "[i] Cannot write to /usr/lib; skipping linux-kbuild restore from host mount."
        return 0
    fi

    echo "[i] Restoring linux-kbuild-${kbuild_ver} from host mount (${HOST_USR_LIB_MOUNT}) ..."
    sudo rm -rf "${local_kbuild_dir}" 2>/dev/null || true
    sudo cp -a "${host_kbuild_dir}" "${local_kbuild_dir}"
}

resolve_kbuild_dir() {
    if has_kbuild_tree "${KBUILD_DIR}"; then
        return 0
    fi

    echo "[i] Missing or incomplete kernel headers for ${KVER}."
    restore_kbuild_from_host_mount
    if has_kbuild_tree "${KBUILD_DIR}"; then
        return 0
    fi

    if can_write_usr_src; then
        echo "[i] Trying to install matching headers inside this environment ..."
        # Bounded timeouts + no retries so a missing network fails fast instead
        # of hanging the AP container start (offline-safe).
        apt_noninteractive -o Acquire::Retries=0 \
            -o Acquire::http::Timeout=5 -o Acquire::https::Timeout=5 update -y || true
        if pkg_available "linux-headers-${KVER}"; then
            apt_noninteractive install -y "linux-headers-${KVER}" || true
        else
            echo "[i] Package linux-headers-${KVER} is not available in current APT repositories."
        fi
    else
        echo "[i] /usr/src is not writable (likely a read-only host mount). Skipping in-container header install."
    fi

    if has_kbuild_tree "${KBUILD_DIR}"; then
        return 0
    fi
    if has_kbuild_tree "${ALT_KBUILD_DIR}"; then
        KBUILD_DIR="${ALT_KBUILD_DIR}"
        return 0
    fi

    echo "ERROR: Could not find a usable kernel build tree for running kernel '${KVER}'."
    echo "Checked:"
    echo "  - ${KBUILD_DIR}"
    echo "  - ${ALT_KBUILD_DIR}"
    if [[ -L "/lib/modules/${KVER}/build" ]]; then
        echo "Current /lib/modules/${KVER}/build symlink -> $(readlink /lib/modules/${KVER}/build)"
    fi
    echo
    echo "Install matching headers on the host and ensure they are mounted into the container."
    echo "Host command:"
    echo "  sudo apt install linux-headers-\$(uname -r)"
    echo "If that exact package is unavailable in your distro repos, boot a kernel version that does have matching headers, then retry."
    exit 1
}

resolve_kbuild_dir

### ---- Download the code and parche ----------------------------------
# Start from clean work files each run; patch80211.sh keeps a per-branch cache
# under ./cache/ so an offline rebuild can reuse previously fetched sources.
rm -f mac80211_hwsim.c mac80211_hwsim.h mac80211_hwsim.c.bak
if ! bash patch80211.sh; then
    echo "ERROR: could not obtain/patch mac80211_hwsim sources (offline and no cached copy?)."
    echo "       Build once while online, then offline starts will reuse the installed module."
    exit 1
fi

# Scope the flood/DoS detector to ONLY the DoS-challenge APs (SAE downgrade,
# 6 GHz, OWE). Without an allowlist the in-kernel detector kicks EVERY flooded
# AP, which self-DoSes the WPA3-SAE online-bruteforce target (wifi-management)
# and the WPA2 PMKID target (wifi-campus). The BSSIDs come from wlan_config so
# they stay in sync. Keep the set aligned with the interface list in
# APs/config/patch_deauth_on_drop_dmesg.sh.
PATCH_ALLOW_BSSIDS=""
for _wlan_cfg in /root/wlan_config /root/wlan_config.clear; do
    if [[ -r "$_wlan_cfg" ]]; then
        # shellcheck disable=SC1090
        source "$_wlan_cfg"
        break
    fi
done
PATCH_ALLOW_BSSIDS="$(printf '%s,%s,%s' "${MAC_DOWNGRADE:-}" "${MAC_6GHZ:-}" "${MAC_OWE:-}")"
# Defensive: strip any stray quotes/whitespace an env_file quirk might leave, so a
# malformed token can't trip dragondrain.sh's strict MAC regex and abort the build.
PATCH_ALLOW_BSSIDS="${PATCH_ALLOW_BSSIDS//[\'\" ]/}"
if [[ "$PATCH_ALLOW_BSSIDS" == ",," ]]; then
    echo "WARNING: no challenge BSSIDs (MAC_DOWNGRADE/MAC_6GHZ/MAC_OWE) in environment;" >&2
    echo "         hwsim flood/DoS detector will apply to ALL APs (self-DoSes wacker/PMKID)." >&2
fi

PATCH_ALLOW_BSSIDS="$PATCH_ALLOW_BSSIDS" \
PATCH_SAE_AUTH_THRESHOLD=4 PATCH_DETECT_WINDOWS=2 bash dragondrain.sh --simulate-dos

# Fold the BSSID allowlist into MODULE_VERSION so the module's identity changes
# whenever the scoped set changes. MODULE_VERSION is otherwise a fixed constant
# (patch80211.sh), so once ANY build is installed on the host-bind-mounted
# /lib/modules, the version-match early-exit below refuses to recompile -- a stale
# detect-all module then keeps self-DoSing wifi-management (wacker) and wifi-campus
# (PMKID) even after the allowlist is corrected. Tagging forces a rebuild on change
# and makes the active scope visible in `modinfo -F version` / /sys/module/*/version.
if [[ -n "$PATCH_ALLOW_BSSIDS" && "$PATCH_ALLOW_BSSIDS" != ",," ]]; then
    PATCH_ALLOW_TAG="scope-$(printf '%s' "$PATCH_ALLOW_BSSIDS" | tr 'A-F' 'a-f' | sha1sum | cut -c1-8)"
else
    PATCH_ALLOW_TAG="noscope"
fi
perl -0777 -i -pe 's{MODULE_VERSION\("([^"]*?WiFiChallengeLab-version)(?:\+[0-9a-z-]+)?"\)}{MODULE_VERSION("$1+'"$PATCH_ALLOW_TAG"'")}g' mac80211_hwsim.c
echo "[i] MODULE_VERSION allowlist tag: +${PATCH_ALLOW_TAG}"

TARGET_VERSION_ERROR="2.5.1-WiFiChallengeLab-version"
TARGET_VERSION=$(grep -oP 'MODULE_VERSION\("([^"]+)"\)' mac80211_hwsim.c | grep -oP '(?<=")[^"]+(?=")' || echo $TARGET_VERSION_ERROR)

### ---- Compile and install
BUILD_DIR="$PWD"
DEST_DIR="/lib/modules/${KVER}/kernel/drivers/net/wireless"
ALT_MOD_PATH="${DEST_DIR}/${ALT_MODNAME}.ko"

# helper – return MODULE_VERSION string or "none"
modver() { modinfo -F version "$1" 2>/dev/null || echo "none"; }

echo "==> Checking existing installation …"
ALT_VER_INSTALLED="$(modver "${ALT_MOD_PATH}")"
echo "Installed WiFiChallenge version : ${ALT_VER_INSTALLED}"

if [[ "${ALT_VER_INSTALLED}" == "${TARGET_VERSION}" ]]; then
    echo "Desired version already present; nothing to do."
    exit 0
fi
echo "Version differs – proceeding with build/install."


# 2. Generate a minimal Kbuild wrapper to rename the module
cat > Kbuild <<EOF
obj-m := ${ALT_MODNAME}.o
${ALT_MODNAME}-objs := mac80211_hwsim.o
EOF

echo "==> Building ${ALT_MODNAME}.ko …"
SKIP_BTF=1 make -s -C "${KBUILD_DIR}" M="${BUILD_DIR}" modules

# verify version of freshly‑built binary
NEW_VER="$(modver "./${ALT_MODNAME}.ko")"
if [[ "${NEW_VER}" != "${TARGET_VERSION}" ]]; then
    echo "❌  Build produced version ‘${NEW_VER}’,"
    echo "    but script expects ‘${TARGET_VERSION}’.  Aborting."
    exit 1
fi

echo "==> Installing to ${DEST_DIR} …"
sudo cp -f "./${ALT_MODNAME}.ko" "${DEST_DIR}/"

echo "==> Updating depmod …"
sudo depmod -a

echo "==> Reloading module …"
# The renamed module shares the stock module's kernel-global resources
# (MAC80211_HWSIM genetlink family + mac80211_hwsim sysfs class), so a loaded
# stock mac80211_hwsim would make the later insert fail with EBUSY. Evict both.
if lsmod | grep -q "^${STOCK_MODNAME}\b"; then
    echo "==> Stock ${STOCK_MODNAME} is loaded; removing it first …"
    sudo modprobe -r "${STOCK_MODNAME}" 2>/dev/null || true
fi
sudo modprobe -r "${ALT_MODNAME}" 2>/dev/null || true
#sudo insmod "${DEST_DIR}/${ALT_MODNAME}.ko" radios=2 channels=1

echo "Installed ${ALT_MODNAME}.ko  (version ${TARGET_VERSION})"
