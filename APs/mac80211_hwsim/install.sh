#!/usr/bin/env bash
#
# install_hwsim.sh – build a side‑by‑side mac80211_hwsim with a
#                    fixed target version.
#
# set -euo pipefail

### ---- configuration -------------------------------------------------
ALT_MODNAME="mac80211_hwsim_WiFiChallenge"
STOCK_MODNAME="mac80211_hwsim"
# ----------------------------------------------------------------------

sudo apt update -y || true
sudo apt install linux-headers-$(uname -r) -y || true
sudo apt-get install -y gcc-12 g++-12 build-essential || true

### ---- Download the code and parche ----------------------------------
bash patch80211.sh

bash dragondrain.sh

TARGET_VERSION_ERROR="2.4-WiFiChallengeLab-version"
TARGET_VERSION=$(grep -oP 'MODULE_VERSION\("([^"]+)"\)' mac80211_hwsim.c | grep -oP '(?<=")[^"]+(?=")' || echo $TARGET_VERSION_ERROR)

### ---- Compile and install
KVER="$(uname -r)"
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
make -s -C "/lib/modules/${KVER}/build" M="${BUILD_DIR}" modules

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
