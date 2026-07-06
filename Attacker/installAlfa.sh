#!/usr/bin/env bash
# Install drivers + firmware for the common USB Wi-Fi adapters used in wireless
# pentesting (Alfa Network and compatible), so any of them can be used from the
# attacker container on any Linux host (monitor mode + packet injection included).
#
# IMPORTANT: USB Wi-Fi adapters are driven by the *host* kernel that the
# (privileged) container shares. Out-of-tree drivers are shipped here as DKMS
# sources and (re)built against the running kernel; at image-build time there
# are usually no headers for the runtime host kernel, so every DKMS build is
# best-effort. The lab compose mounts /lib/modules and /usr/src, so the modules
# are ultimately built/loaded against the host kernel. For that reason this
# script never aborts on a single missing package or failed build.
#
# Alfa adapter -> chipset -> driver coverage:
#   AWUS036H              RTL8187     rtl8187      (in-kernel) + firmware-realtek
#   AWUS036NH            RT3070      rt2800usb    (in-kernel) + firmware-ralink
#   AWUS036NHA           AR9271      ath9k_htc    (in-kernel) + firmware-atheros
#   AWUS036NEH           RTL8188EUS  realtek-rtl8188eus-dkms
#   AWUS036N / clones    RTL8188FU   realtek-rtl8188fu-dkms
#   AWUS036AC/ACH        RTL8812AU   realtek-rtl88xxau-dkms
#   AWUS1900             RTL8814AU   realtek-rtl8814au-dkms
#   AWUS036ACHM          RTL8811CU/8821CU  realtek-rtl8821cu-dkms (or morrownr src)
#   AC1300-class         RTL8822BU   88x2bu       (morrownr src)
#   AWUS036ACM           MT7612U     mt76x2u      (in-kernel) + firmware-mediatek
#   AWUS036ACS           MT7610U     mt76x0u      (in-kernel) + firmware-mediatek
#   AWUS036AXM(L)        MT7921U     mt7921u      (in-kernel) + firmware-mediatek

set +e   # best-effort: never abort the image build on a missing pkg / DKMS build
export DEBIAN_FRONTEND=noninteractive

if [ "$(id -u)" -ne 0 ]; then
  echo "Please run as root" >&2
  exit 1
fi

apt-get update

# --- DKMS toolchain + kernel headers (needed to (re)build the out-of-tree drivers)
apt-get install -y dkms build-essential bc git ca-certificates libelf-dev
# Headers for the running kernel first (host/VM), then the Kali metapackage.
apt-get install -y "linux-headers-$(uname -r)" || apt-get install -y linux-headers-amd64 || true

# --- Firmware for the in-kernel Alfa chipsets --------------------------------
# Names differ across Debian/Kali releases; install each tolerantly.
for fw in firmware-atheros firmware-ralink firmware-realtek \
          firmware-mediatek firmware-misc-nonfree firmware-linux-nonfree; do
  apt-get install -y "$fw" || true
done

# --- Out-of-tree DKMS drivers (packaged in Kali) -----------------------------
# Install each tolerantly so a renamed/absent package never breaks the build.
for drv in realtek-rtl88xxau-dkms realtek-rtl8814au-dkms \
           realtek-rtl8188eus-dkms realtek-rtl8188fu-dkms \
           realtek-rtl8821cu-dkms; do
  apt-get install -y "$drv" || true
done

# --- Source fallbacks for drivers that may not be packaged (or fail to build) --
# Staged from the well-maintained aircrack-ng / morrownr DKMS trees, and only when
# an equivalent driver isn't already registered. dkms records the source so the
# module is (re)built against the host kernel at runtime; every step is best-effort
# and never aborts the build (a missing repo / failed build is skipped).
mkdir -p /opt/wifi-drivers

stage_dkms_src() {   # $1 = dkms grep key   $2 = git url   $3 = in-repo build command
  local key="$1" url="$2" build="$3" dir
  dkms status 2>/dev/null | grep -qiE "$key" && return 0
  dir="/opt/wifi-drivers/$(basename "${url%.git}")"
  [ -d "$dir" ] || git clone --depth 1 "$url" "$dir" || return 0
  ( cd "$dir" && eval "$build" ) || true
}

stage_dkms_src '8812au|88xxau' https://github.com/aircrack-ng/rtl8812au.git    'make dkms_install'   # RTL8812AU / RTL8821AU (AWUS036AC/ACH)
stage_dkms_src '8821cu|8811cu' https://github.com/morrownr/8821cu-20210916.git './dkms-install.sh'   # RTL8811CU / RTL8821CU (AWUS036ACHM)
stage_dkms_src '88x2bu|8822bu' https://github.com/morrownr/88x2bu-20210702.git './dkms-install.sh'   # RTL8822BU (AC1300-class)

echo
echo "[+] Alfa adapter drivers/firmware install finished (best effort)."
dkms status 2>/dev/null || true
