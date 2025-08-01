ALT_MODNAME="mac80211_hwsim_WiFiChallenge"

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