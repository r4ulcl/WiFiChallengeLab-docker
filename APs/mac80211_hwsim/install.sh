#!/usr/bin/env bash
#
# install_hwsim.sh – build a side‑by‑side mac80211_hwsim with a
#                    fixed target version.
#
# set -euo pipefail

### ---- configuration -------------------------------------------------
ALT_MODNAME="mac80211_hwsim_WiFiChallenge"
STOCK_MODNAME="mac80211_hwsim"
AUTO_INSTALL_DEPS="${AUTO_INSTALL_DEPS:-0}"
HOST_USR_LIB_MOUNT="${HOST_USR_LIB_MOUNT:-/host_usr_lib}"
# ----------------------------------------------------------------------

require_cmds=()
for c in make gcc g++; do
    command -v "${c}" >/dev/null 2>&1 || require_cmds+=("${c}")
done

if (( ${#require_cmds[@]} > 0 )); then
    if [[ "${AUTO_INSTALL_DEPS}" == "1" ]]; then
        echo "[i] Missing build tools (${require_cmds[*]}). Installing ..."
        sudo apt-get install -y gcc-12 g++-12 build-essential
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
        sudo apt update -y || true
        if pkg_available "linux-headers-${KVER}"; then
            sudo apt install "linux-headers-${KVER}" -y || true
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
rm -f mac80211_hwsim.c mac80211_hwsim.h mac80211_hwsim.c.bak
bash patch80211.sh

PATCH_SAE_AUTH_THRESHOLD=4 PATCH_DETECT_WINDOWS=2 bash dragondrain.sh --simulate-dos

TARGET_VERSION_ERROR="2.4.1-WiFiChallengeLab-version"
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
sudo modprobe -r "${ALT_MODNAME}" 2>/dev/null || true
#sudo insmod "${DEST_DIR}/${ALT_MODNAME}.ko" radios=2 channels=1

echo "Installed ${ALT_MODNAME}.ko  (version ${TARGET_VERSION})"
