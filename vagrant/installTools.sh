#!/usr/bin/env bash
#set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND="noninteractive"

# Debian 12+ PEP-668 guardrail: `pip install` into the system interpreter aborts
# with "externally-managed-environment" unless --break-system-packages is passed.
# This script is invoked as `sudo bash installTools.sh`, and sudo strips the
# PIP_BREAK_SYSTEM_PACKAGES that install.sh exported, so pip calls made *inside*
# makefiles / setup.py (wifipumpkin3, assless-chaps, wifi_db, ...) that we cannot
# add a flag to were failing. Export it here so every pip invocation is covered.
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_DISABLE_PIP_VERSION_CHECK=1

. /etc/os-release
DEB_CODENAME="${VERSION_CODENAME:-bookworm}"

# --- lock working DNS for the duration of the install ---
set +e
RESOLV_BAK="/root/resolv.conf.pre-install.$(date +%s)"
if [ -e /etc/resolv.conf ]; then
  cp -a /etc/resolv.conf "$RESOLV_BAK"
fi

# If /etc/resolv.conf is a symlink, replace it temporarily with a real file
if [ -L /etc/resolv.conf ]; then
  rm -f /etc/resolv.conf
fi

cat >/etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
options timeout:2 attempts:2
EOF

# Make it immutable so nothing flips it to 127.0.0.1 mid-install.
chattr +i /etc/resolv.conf 2>/dev/null || true

# IMPORTANT: this lock is TEMPORARY. Always release it (and hand DNS back to
# systemd-resolved / NetworkManager) when this script exits, however it exits.
# Leaving /etc/resolv.conf immutable and pinned to 1.1.1.1/8.8.8.8 was the root
# cause of "DNS works on my network but not on theirs" across VirtualBox, VMware,
# QEMU and Hyper-V (any network blocking those resolvers had no working DNS, and
# the user could not fix it because the file was immutable).
__restore_resolv_conf() {
  set +e
  chattr -i /etc/resolv.conf 2>/dev/null || true
  rm -f /etc/resolv.conf
  if [ -e "$RESOLV_BAK" ] || [ -L "$RESOLV_BAK" ]; then
    mv -f "$RESOLV_BAK" /etc/resolv.conf
  elif [ -e /run/systemd/resolve/stub-resolv.conf ]; then
    ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
  fi
}
trap __restore_resolv_conf EXIT

# Prevent package post-install scripts from starting daemons in the middle of
# provisioning. In particular, isc-dhcp-server starts before install.sh can
# disable it. Restore any pre-existing policy when this script exits.
POLICY_RC_BAK="/root/policy-rc.d.pre-install.$(date +%s)"
if [ -e /usr/sbin/policy-rc.d ]; then
  cp -a /usr/sbin/policy-rc.d "$POLICY_RC_BAK"
fi
cat >/usr/sbin/policy-rc.d <<'EOF'
#!/bin/sh
exit 101
EOF
chmod 0755 /usr/sbin/policy-rc.d
__restore_policy_rc() {
  set +e
  rm -f /usr/sbin/policy-rc.d
  if [ -e "$POLICY_RC_BAK" ]; then
    mv -f "$POLICY_RC_BAK" /usr/sbin/policy-rc.d
  fi
}
trap '__restore_resolv_conf; __restore_policy_rc' EXIT

# Fail loudly and stop if a tool build aborts the script. Historically one build
# error (e.g. hostapd-mana missing its .config) tripped `set -e` and every tool
# after it - including hcxdumptool 7.1.2 - was silently skipped. Report it as
# CRITICAL so the provisioner aborts instead of shipping a half-built image.
# Only fatal inside `set -e` regions; the `set +e` best-effort blocks are exempt.
__installtools_failed() {
    local code=$?
    case $- in *e*) ;; *) return 0 ;; esac
    echo ""                                                            >&2
    echo "############################################################" >&2
    echo "# CRITICAL: installTools.sh aborted (exit ${code})"          >&2
    echo "#   at line ${1}: ${2}"                                      >&2
    echo "#   Wireless toolkit is INCOMPLETE - provisioning stopped."  >&2
    echo "############################################################" >&2
    exit "${code}"
}
trap '__installtools_failed "${LINENO}" "${BASH_COMMAND}"' ERR

# quick sanity check
getent hosts deb.debian.org >/dev/null || echo "Warning: DNS check failed"
set -e


cd ~
FOLDER="$(pwd)"
TOOLS="${FOLDER}/tools"
mkdir -p "${TOOLS}"

apt-get update
apt-get install -y wget curl git ca-certificates build-essential acl

# ---------- basic utilities ---------------------------------------------------
apt-get install -y nmap python3 python3-pip wpagui sqlite3 tshark jq p7zip-full iptables dnsmasq-base

# ---------- Python 2 availability check --------------------------------------
have_py2_pkg=false
if apt-cache show python2 >/dev/null 2>&1; then
  apt-get install -y python2 || true
  if apt-cache show python2-dev >/dev/null 2>&1; then
    apt-get install -y python2-dev || true
  fi
  if command -v python2 >/dev/null 2>&1; then have_py2_pkg=true; fi
fi

if ! $have_py2_pkg; then
  # Fallback to pyenv for Python 2.7 on Debian 12 and 13
  if ! command -v git >/dev/null; then apt-get install -y git; fi
  if [ ! -d /usr/local/pyenv ]; then
    git clone https://github.com/pyenv/pyenv.git /usr/local/pyenv
  fi
  export PYENV_ROOT="/usr/local/pyenv"
  export PATH="$PYENV_ROOT/bin:$PATH"
  eval "$(pyenv init -)" || true
  if ! pyenv versions --bare | grep -q '^2\.7\.18$'; then
    apt-get install -y libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev
    CFLAGS="-O2" pyenv install 2.7.18 || true
  fi
  PY2_PREFIX="$(pyenv root)/versions/2.7.18"
  if [ -x "${PY2_PREFIX}/bin/python" ]; then
    ln -sf "${PY2_PREFIX}/bin/python" /usr/local/bin/python2
    [ ! -x "${PY2_PREFIX}/bin/pip" ] || ln -sf "${PY2_PREFIX}/bin/pip" /usr/local/bin/pip2
  else
    echo "Warning: Python 2.7.18 could not be built; legacy Python 2 tools will be unavailable"
    rm -f /usr/local/bin/python2 /usr/local/bin/pip2
  fi
  # Keep pyenv's generic `python` shim on the system interpreter. Only the
  # explicit python2/pip2 shims above should select the legacy runtime.
  pyenv global system || true
  hash -r || true
fi

# Keep the system `python` command on Python 3 (python-is-python3 is installed by
# install.sh). Legacy tools invoke python2 explicitly through the shim above.

# ---------- wordlists ---------------------------------------------------------
# These downloads are non-critical and use flaky public endpoints (GitHub release
# CDN + raw.githubusercontent). Under `set -e` an unguarded transient failure here
# silently aborts the whole toolkit build, so each download is guarded.
# NOTE: `curl | head` makes curl exit 23 ("Failure writing output to destination")
# by design once head closes the pipe after 1,000,000 lines -- that is expected and
# harmless; -sL keeps curl quiet so it is not mistaken for the real error.
cd "${FOLDER}"
curl -sL --retry 3 --retry-delay 2 \
  https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt \
  | head -n 1000000 > rockyou-top100000.txt || true
[ -s rockyou-top100000.txt ] || echo "Warning: rockyou-top100000.txt is empty; check network/disk"

wget -q --tries=3 --timeout=30 \
  https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt \
  || echo "Warning: top-usernames-shortlist.txt download failed, continuing"

# ---------- EAP_buster --------------------------------------------------------
cd "${TOOLS}"
[ ! -d EAP_buster ] && git clone https://github.com/blackarrowsec/EAP_buster

# ---------- OpenSSL local build if needed ------------------------------------
apt-get install -y checkinstall zlib1g-dev
cd /usr/local/src
OPENSSL_VER="openssl-3.2.1"
if ! openssl version | grep -qE 'OpenSSL 3\.'; then
  if [ ! -d "${OPENSSL_VER}" ]; then
    wget -q https://www.openssl.org/source/${OPENSSL_VER}.tar.gz
    tar xf ${OPENSSL_VER}.tar.gz && rm ${OPENSSL_VER}.tar.gz
    cd ${OPENSSL_VER}
    ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
    make -j "$(nproc)" && make install
    ln -sf /usr/local/openssl/bin/openssl /usr/local/bin/openssl
  fi
fi

# ---------- hcxtools ---------------------------------------------------------
# The old airgeddon .deb downgrades hcxtools and pulls libssl1.1, which is not
# available on Debian 12 and leaves dpkg broken. Use the distro package.
cd "${TOOLS}"
apt-get install -y hcxtools pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc

# ---------- wifi_db -----------------------------------------------------------
# DB Browser for SQLite (Qt GUI) to inspect wifi_db's database on the GNOME
# desktop; the sqlite3 CLI installed earlier stays as the headless fallback.
apt-get install -y sqlitebrowser
cd "${TOOLS}"
if [ ! -d wifi_db ]; then
  git clone https://github.com/r4ulcl/wifi_db
  cd wifi_db
  python3 -m pip install --break-system-packages -r requirements.txt || python3 -m pip install -r requirements.txt
fi

# ---------- pcapFilter helper -------------------------------------------------
cd "${TOOLS}"
apt-get install -y xxd
wget -q https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/14c25daf9e7ef54e54f53d5a72b2bcd627967ad8/pcapFilter.sh -O pcapFilter.sh
chmod +x pcapFilter.sh

# ---------- UnicastDeauth -----------------------------------------------------
cd "${TOOLS}"
git clone https://github.com/mamatb/UnicastDeauth.git || true
python3 -m pip install --break-system-packages -r UnicastDeauth/requirements.txt || python3 -m pip install -r UnicastDeauth/requirements.txt

# ---------- EapHammer ----------------------------------------------------
cd "${TOOLS}"
if [ ! -d eaphammer ]; then
  git clone https://github.com/r4ulcl/eaphammer
  cd eaphammer
  while read -r dep; do
    apt-get install -y "$dep" || apt-get -y --fix-broken install || true
  done < kali-dependencies.txt
  apt-get install -y dsniff apache2 libffi-dev python3-openssl
  systemctl disable --now apache2 || true
  ./ubuntu-unattended-setup || echo "eaphammer unattended setup failed, continuing"
  python3 -m pip install --break-system-packages --upgrade flask flask_cors flask_socketio pywebcopy gevent netifaces || true
  wget -q https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini || true
fi
ln -sf /usr/bin/python3 /usr/bin/python3.8 || true
#python3 -m pip install aioquic || true
pip3 install tqdm pem aioquic --break-system-packages || true
if [ -f "${TOOLS}/eaphammer/pip.req" ]; then
  python3 -m pip install --break-system-packages -r "${TOOLS}/eaphammer/pip.req" || python3 -m pip install -r "${TOOLS}/eaphammer/pip.req"
else
  echo "Warning: ${TOOLS}/eaphammer/pip.req not found; skipping eaphammer pip.req install"
fi
# Eaphammer's cert_wizard still uses OpenSSL.crypto.X509Req(), so reinstall a
# pyOpenSSL release that retains that legacy API after its own requirements run.
python3 -m pip install --break-system-packages --force-reinstall 'pyOpenSSL<26.2'

# ---------- hostapd-wpe 2.11 -------------------------------------------------
cd "${TOOLS}"
apt-get install -y libsqlite3-dev libnl-3-dev libnl-genl-3-dev libssl-dev pkg-config
HOSTAPD_WPE_SRC="${TOOLS}/hostapd-2.11"
HOSTAPD_WPE_PATCH="${TOOLS}/hostapd-2.11-wpe.patch"

# Build from fresh upstream source during clean-system provisioning.
if ! command -v hostapd-wpe >/dev/null 2>&1; then
  wget -q https://w1.fi/releases/hostapd-2.11.tar.gz -O hostapd-2.11.tar.gz
  tar zxf hostapd-2.11.tar.gz
  rm -f hostapd-2.11.tar.gz

  wget -q https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch \
    -O "${HOSTAPD_WPE_PATCH}"

  # The upstream WPE patch was generated against a slightly older 2.11 tree:
  # its first TLS hunk removes openssl/rand.h, which is already absent from the
  # published tarball. Drop that obsolete hunk so patch does not incorrectly
  # classify and skip every remaining tls_openssl.c hunk.
  sed -i '/^@@ -29,7 +29,6 @@$/,/^@@ -50,6 +49,7 @@$/ {
    /^@@ -50,6 +49,7 @@$/!d
  }' "${HOSTAPD_WPE_PATCH}"

  cd "${HOSTAPD_WPE_SRC}"
  # --ignore-whitespace also handles two malformed leading spaces in the
  # upstream main.c hunk without weakening content/context validation.
  patch --batch --forward --ignore-whitespace -p1 < "${HOSTAPD_WPE_PATCH}"
  rm -f "${HOSTAPD_WPE_PATCH}"

  make -C "${HOSTAPD_WPE_SRC}/hostapd" -j"$(nproc)"
  make -C "${HOSTAPD_WPE_SRC}/hostapd" wpe
  # Install explicitly into root's standard PATH instead of relying on the
  # upstream Makefile's BINDIR default.
  install -m0755 "${HOSTAPD_WPE_SRC}/hostapd/hostapd-wpe" /usr/local/sbin/hostapd-wpe
  install -m0755 "${HOSTAPD_WPE_SRC}/hostapd/hostapd_cli-wpe" /usr/local/bin/hostapd_cli-wpe
  cd /etc/hostapd-wpe/certs
  ./bootstrap
  make install
fi
hash -r
command -v hostapd-wpe >/dev/null

# ---------- Aircrack-ng from source ------------------------------------------
cd "${TOOLS}"
apt-get install -y autoconf automake libtool libnl-3-dev libnl-genl-3-dev libpcap-dev libhwloc-dev libcmocka-dev hostapd wpasupplicant tcpdump screen iw usbutils expect rfkill ethtool shtool pkg-config libssl-dev

if [ ! -d aircrack-ng ]; then
  git clone https://github.com/WiFiChallenge/aircrack-ng.git
  cd aircrack-ng
  autoreconf -i
  ./configure
  make -j"$(nproc)"
  make install
  ldconfig
  cd ..
fi

# ---------- Hashcat and utils -------------------------------------------------
cd "${TOOLS}"
apt-get install -y hashcat
if [ ! -d hashcat-6.0.0 ]; then
  wget -q https://hashcat.net/files/hashcat-6.0.0.7z
  7zr x hashcat-6.0.0.7z && rm hashcat-6.0.0.7z
  wget -q https://http.kali.org/kali/pool/main/h/hashcat-utils/hashcat-utils_1.9-0kali2_amd64.deb || true
  # Guard the dpkg: if the download failed the glob does not expand and dpkg would
  # error on the literal "hashcat-utils_*.deb". hashcat-utils is non-critical.
  if ls hashcat-utils_*.deb >/dev/null 2>&1; then
    dpkg -i hashcat-utils_*.deb || apt-get -y --fix-broken install || true
    rm -f hashcat-utils_*.deb
  else
    echo "Warning: hashcat-utils deb download failed; skipping (non-critical)"
  fi
  ln -sf /root/tools/hashcat-6.0.0/hashcat.bin /usr/local/bin/hashcat || true
  echo "alias hashcat='sudo hashcat'" >> /home/user/.bashrc
fi
timeout 60s /usr/local/bin/hashcat -b || true

# ---------- John the Ripper ---------------------------------------------------
cd "${TOOLS}"
apt-get -y install john yasm pkg-config libgmp-dev libbz2-dev
if [ ! -d john/src ]; then
  git clone https://github.com/openwall/john.git john \
    || echo "Warning: could not clone John jumbo; using the distro package"
fi
if [ -d john/src ] && cd john/src && ./configure && make -s clean && make -sj"$(nproc)"; then
  # John resolves its support files relative to the real binary after following
  # the symlink, while aliases are invisible to airgeddon's noninteractive check.
  ln -sfn "${TOOLS}/john/run/john" /usr/local/bin/john
else
  echo "Warning: John jumbo build failed; using the distro john package"
fi
hash -r
command -v john >/dev/null

# ---------- Misc Wi-Fi tools --------------------------------------------------
cd "${TOOLS}"
[ ! -d crEAP ] && git clone https://github.com/Snizz/crEAP
apt-get install -y arp-scan

# asleap legacy debs can be flaky on Debian
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb || true
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/asleap_2.2-1parrot0_amd64.deb || true
dpkg -i libssl1.0.2_*.deb asleap_*.deb || apt-get -y --fix-broken install || true
rm -f libssl1.0.2_*.deb asleap_*.deb

# Bettercap
apt-get install -y golang libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bettercap_2.28-0kali2_amd64.deb || true
dpkg -i bettercap_*.deb || apt-get -y --fix-broken install || true
rm -f bettercap_*.deb

# BeEF
apt-get install -y autoconf bison libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev  libgdbm-dev libdb-dev ruby-bundler nodejs
# Follow BeEF's declared Ruby version instead of pinning an older runtime that
# eventually becomes incompatible with its rolling Gemfile.
if [ ! -d /usr/share/beef ]; then
  git clone https://github.com/beefproject/beef.git /usr/share/beef
else
  git -C /usr/share/beef pull --ff-only || echo "Warning: could not refresh the existing BeEF checkout"
fi
BEEF_RUBY_VER="$(tr -d '[:space:]' </usr/share/beef/.ruby-version 2>/dev/null || true)"
if ! [[ "$BEEF_RUBY_VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  BEEF_RUBY_VER="3.4.7"
fi
if [ ! -d /usr/local/rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv
fi
# rbenv has NO `install` subcommand without the ruby-build plugin. Without it the
# clone above left `rbenv install` failing with "no such command `install'", so
# no managed Ruby was ever built and bundle ran against system Ruby 3.1. Install
# (or refresh) the plugin so `rbenv install` works.
if [ ! -d /usr/local/rbenv/plugins/ruby-build ]; then
  git clone https://github.com/rbenv/ruby-build.git /usr/local/rbenv/plugins/ruby-build
else
  git -C /usr/local/rbenv/plugins/ruby-build pull --ff-only || true
fi
export RBENV_ROOT=/usr/local/rbenv
export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:$PATH"
eval "$(rbenv init - bash)"
rbenv install -s "${BEEF_RUBY_VER}"
rbenv global "${BEEF_RUBY_VER}"
cd /usr/share/beef
if rbenv prefix "${BEEF_RUBY_VER}" >/dev/null 2>&1; then
  rbenv local "${BEEF_RUBY_VER}"
  if gem install bundler \
      && bundle config set --local without 'test' \
      && bundle install; then
    cat >/usr/local/bin/beef <<'EOF'
#!/usr/bin/env bash
export RBENV_ROOT=/usr/local/rbenv
export PATH="${RBENV_ROOT}/bin:${RBENV_ROOT}/shims:${PATH}"
cd /usr/share/beef
exec rbenv exec bundle exec ./beef "$@"
EOF
    chmod 0755 /usr/local/bin/beef
  else
    echo "Warning: BeEF dependencies could not be installed; disabling the BeEF launcher"
    rm -f /usr/local/bin/beef
  fi
else
  echo "Warning: Ruby ${BEEF_RUBY_VER} is unavailable; skipping BeEF bundle install"
  rm -f /usr/local/bin/beef
fi
hash -r
command -v beef >/dev/null

# airgeddon
apt-get install -y lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd ettercap-text-only mdk3 mdk4 arping ccze
systemctl disable --now lighttpd || true
cd "${TOOLS}"
[ ! -d airgeddon ] && git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git
cd airgeddon
chmod 0755 airgeddon.sh
# airgeddon derives its asset directory from $0 before resolving the script
# symlink, so a plain symlink breaks when called outside its checkout.
cat >/usr/local/bin/airgeddon <<'EOF'
#!/usr/bin/env bash
cd /root/tools/airgeddon
exec ./airgeddon.sh "$@"
EOF
chmod 0755 /usr/local/bin/airgeddon
sed -i '/^AIRGEDDON_AUTO_UPDATE=/c\AIRGEDDON_AUTO_UPDATE=false' .airgeddonrc || true
sed -i '/^AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=/c\AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=false' .airgeddonrc || true
cd plugins
[ ! -d airgeddon-plugins ] && git clone --depth 1 https://github.com/OscarAkaElvis/airgeddon-plugins.git
cp airgeddon-plugins/allchars_captiveportal/allchars_captiveportal.sh . || true
cp airgeddon-plugins/wpa3_cookie_guzzler/wpa3_cookie_guzzler.sh . || true
cp airgeddon-plugins/wpa3_cookie_guzzler/wpa3_cookie_guzzler.py . || true
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.sh . || true
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.py . || true
mkdir -p wpa_supplicant_binaries
cp airgeddon-plugins/wpa3_online_attack/wpa_supplicant_binaries/wpa_supplicant_amd64 ./wpa_supplicant_binaries/ || true
rm -rf airgeddon-plugins
git clone --depth 1 https://github.com/Janek79ax/dragon-drain-wpa3-airgeddon-plugin.git || true
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain.sh . || true
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain_attack.py . || true
rm -rf dragon-drain-wpa3-airgeddon-plugin
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bully_1.1.+git20190923-0kali1_amd64.deb || true
dpkg -i bully_*.deb || apt-get -y --fix-broken install || true
rm -f bully_*.deb
hash -r
command -v airgeddon >/dev/null

# Install ath_masker
# NOTE: this builds AND loads a kernel module. Inside a container image build
# there are no headers for the running kernel and modules cannot be loaded, so
# the whole block is best-effort (set +e) to avoid aborting the build; on the
# VM/host it still builds and loads normally.
set +e
cd "${TOOLS}"
git clone --depth 1 https://github.com/vanhoefm/ath_masker
cd ath_masker/
make

mkdir -p "/lib/modules/$(uname -r)/kernel/drivers/net/wireless/"
cp ath_masker.ko "/lib/modules/$(uname -r)/kernel/drivers/net/wireless/"
depmod -a

echo -e "ath\nath_masker" | tee /etc/modules-load.d/ath_masker.conf > /dev/null
echo "softdep ath_masker pre: ath" | tee /etc/modprobe.d/ath_masker.conf > /dev/null

modprobe ath
modprobe ath_masker
cd "${TOOLS}"
rm -rf ath_masker/ 2> /dev/null
set -e


# hostapd-mana
apt-get install -y libnl-genl-3-dev libssl-dev
cd "${TOOLS}"
[ ! -d hostapd-mana ] && git clone https://github.com/sensepost/hostapd-mana
# hostapd's build needs a .config first (verify_config fails without it, same as
# wacker above). Tolerate a build failure so one tool can't abort the whole
# script and skip everything after it (hcxdumptool 7.1.2, wifiphisher, wifite2...).
cd hostapd-mana/hostapd && cp -n defconfig .config && make -j"$(nproc)" || true
cd "${TOOLS}"
ln -sf /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

# eapeak with python2 if present
cd "${TOOLS}"
apt-get install -y swig python3-dev
python3 -m pip install --break-system-packages pipenv || python3 -m pip install pipenv
if [ ! -d eapeak ]; then
  git clone https://github.com/securestate/eapeak
  cd eapeak
  if command -v python2 >/dev/null 2>&1; then
    # Modern virtualenv no longer supports Python 2. Do not invoke it; eapeak
    # remains available as source for legacy use.
    echo "Warning: Python 2 is present but modern pipenv cannot create a Python 2 environment; skipping eapeak virtualenv"
  else
    echo "python2 not available, skipping Python 2 pipenv for eapeak"
  fi
fi

# reaver fork
apt-get install -y libpcap-dev
cd "${TOOLS}"
if [ ! -d reaver-wps-fork-t6x ]; then
  git clone https://github.com/t6x/reaver-wps-fork-t6x
  cd reaver-wps-fork-t6x*/src
  ./configure && make -j"$(nproc)" && make install
fi

# SensePost tools
cd "${TOOLS}"
[ ! -d wpa_sycophant ] && git clone https://github.com/sensepost/wpa_sycophant
cd wpa_sycophant && make -C wpa_supplicant -j"$(nproc)" || true

cd "${TOOLS}"
[ ! -d berate_ap ] && git clone https://github.com/sensepost/berate_ap

# OpenSSL legacy provider enable
CONF_DIR=$(openssl version -d | awk -F'"' '{print $2}')
OPENSSL_CNF="$CONF_DIR/openssl.cnf"
if [[ -f "$OPENSSL_CNF" ]] && ! grep -q "\[legacy_sect\]" "$OPENSSL_CNF"; then
  BACKUP="$OPENSSL_CNF.bak.$(date +%s)"
  cp "$OPENSSL_CNF" "$BACKUP"
  cat <<'EOF' >> "$OPENSSL_CNF"

# Added to enable OpenSSL 3 legacy provider
openssl_conf = openssl_init
[openssl_init]
providers = provider_sect
[provider_sect]
default = default_sect
legacy  = legacy_sect
[default_sect]
activate = 1
[legacy_sect]
activate = 1
EOF
  echo "Legacy provider enabled. Backup at $BACKUP"
fi

# mdk4
apt-get install -y pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev
cd "${TOOLS}"
[ ! -d mdk4 ] && git clone https://github.com/aircrack-ng/mdk4
# -Wno-unterminated-string-initialization silences ~500 harmless warnings GCC 15
# emits on mdk4's manufactor.h OUI table (no -Werror upstream, so cosmetic only).
# IMPORTANT: pass the suppression as an ENVIRONMENT assignment (before `make`),
# NOT as a `make CFLAGS=...` command-line override. A command-line CFLAGS wins
# over the Makefile's `CFLAGS += $(pkg-config --cflags libnl-3.0 libnl-genl-3.0)`
# and `-Iosdep`, stripping the netlink/pcap include paths -- which made
# channelhopper.c (netlink/genl/genl.h) and file.c (LINKTYPE_*/TCPDUMP_MAGIC)
# fail to compile and silently skipped `make install`. As an env var it seeds the
# `?=` default and the Makefile's `+=` still appends the includes, so the build
# both suppresses the noise and keeps its include paths.
cd mdk4 && CFLAGS="-g -O3 -Wall -Wextra -fcommon -Wno-unterminated-string-initialization" make -j"$(nproc)" && make install

# air-hammer with python2 if available
cd "${TOOLS}"
[ ! -d air-hammer ] && git clone https://github.com/Wh1t3Rh1n0/air-hammer
cd air-hammer
if command -v python2 >/dev/null 2>&1; then
  curl -sS https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
  python2 get-pip.py || true
  pip2 install -U setuptools wpa_supplicant service_identity || true
fi

# Wifipumpkin3
apt-get install -y python3-dev libssl-dev libffi-dev build-essential \
  python3-pyqt5 python3-bs4 python3-dnslib python3-dnspython python3-flask-restful \
  python3-isc-dhcp-leases python3-netaddr python3-scapy python3-tabulate \
  python3-termcolor python3-twisted python3-urwid
cd "${TOOLS}"
[ ! -d wifipumpkin3 ] && git clone https://github.com/P0cL4bs/wifipumpkin3.git
# PIP_IGNORE_INSTALLED: the makefile's `pip install` pins old deps (urwid 2.1.2,
# dnslib, dhcplib...) and tries to uninstall the apt-provided ones, which fails
# with "uninstall-no-record-file" for distro packages. Skip uninstalls instead.
cd wifipumpkin3 && sed -i 's/python3.7/python3/g' makefile && PIP_IGNORE_INSTALLED=1 make install || true

# convenience
chown -R user:user "${TOOLS}"
ln -sf "${TOOLS}" /home/user/tools || true

# /usr/bin/hostapd-mana points into /root/tools. Allow the lab user to traverse
# the path and all tool subdirectories so the shell can find commands without
# exposing /root itself for directory listing.
setfacl -m u:user:--x /root
setfacl -R -m u:user:--x "${TOOLS}"

# Wireshark GUI for the GNOME desktop. Preseed the setuid-dumpcap prompt to "yes"
# (noninteractive install would otherwise default to no) and add the lab user to
# the wireshark group so packet capture works without running the GUI as root.
echo "wireshark-common wireshark-common/install-setuid boolean true" | debconf-set-selections
apt-get install -y macchanger wireshark
usermod -aG wireshark user || true

# Wacker
cd "${TOOLS}"
[ ! -d wacker ] && git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
apt-get install -y pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools
cp defconfig wpa_supplicant-2.10/wpa_supplicant/.config
git apply wpa_supplicant.patch || true
cd wpa_supplicant-2.10/wpa_supplicant && make -j"$(nproc)" || true

# Build hcxtools and hcxdumptool from their upstream default branches as a
# matched pair. The distro hcxtools is older, while the old hcxdumptool snapshot
# uses SIOCGSTAMP and fails on modern glibc.
cd "${TOOLS}"
apt-get install -y libpcap-dev pkg-config gcc make libcurl4-openssl-dev libssl-dev zlib1g-dev
if [ ! -d hcxtools-src/.git ]; then
  rm -rf hcxtools-src
  git clone https://github.com/ZerBea/hcxtools.git hcxtools-src
else
  git -C hcxtools-src remote set-url origin https://github.com/ZerBea/hcxtools.git
  if [ -f hcxtools-src/.git/shallow ]; then
    git -C hcxtools-src fetch --unshallow --tags origin
  fi
  git -C hcxtools-src fetch --tags origin master
  git -C hcxtools-src checkout -B wcl-current FETCH_HEAD
fi
cd hcxtools-src
make -j"$(nproc)" && make install

cd "${TOOLS}"
if [ ! -d hcxdumptool-src/.git ]; then
  rm -rf hcxdumptool-src
  git clone https://github.com/ZerBea/hcxdumptool.git hcxdumptool-src
else
  git -C hcxdumptool-src remote set-url origin https://github.com/ZerBea/hcxdumptool.git
  if [ -f hcxdumptool-src/.git/shallow ]; then
    git -C hcxdumptool-src fetch --unshallow --tags origin
  fi
  git -C hcxdumptool-src fetch --tags origin master
  git -C hcxdumptool-src checkout -B wcl-current FETCH_HEAD
fi
cd hcxdumptool-src
make -j"$(nproc)" && make install
hash -r || true

# Wifiphisher
cd "${TOOLS}"
[ ! -d extra-phishing-pages ] && git clone https://github.com/wifiphisher/extra-phishing-pages
[ ! -d wifiphisher ] && git clone https://github.com/wifiphisher/wifiphisher.git
cd wifiphisher && python3 setup.py install || true

# Wifite2
cd "${TOOLS}"
[ ! -d wifite2 ] && git clone https://github.com/derv82/wifite2.git
cd wifite2 && python3 setup.py install || true

# assless-chaps
cd "${TOOLS}"
[ ! -d assless-chaps ] && git clone https://github.com/sensepost/assless-chaps
python3 -m pip install pycryptodome || true
bzip2 -d assless-chaps/10-million-password-list-top-1000000.db.bz2 || true


# dragondrain
cd "${TOOLS}"
# Skip clone if already present (re-provision) and tolerate transient failures.
[ ! -d dragondrain-and-time ] && git clone https://github.com/vanhoefm/dragondrain-and-time || true
apt-get update
apt-get install autoconf automake libtool shtool libssl-dev pkg-config -y

cd dragondrain-and-time

make distclean 2>/dev/null || true

autoreconf -i
CFLAGS='-D__packed="__attribute__((__packed__))"' ./configure
make

# Link dragondrain to airgeddon plugin
sudo chmod +x "${TOOLS}/dragondrain-and-time/src/dragondrain"
sudo ln -sf "${TOOLS}"/dragondrain-and-time/src/dragondrain /usr/local/bin/dragondrain 

###############################################################################
# Optional: enable SSH on port 2222 (commented out by default)
###############################################################################
# apt-get install -y ssh
# echo 'Port 2222' >> /etc/ssh/sshd_config && systemctl enable --now ssh


echo -e "\n[+] Wireless assessment toolkit installed under ${TOOLS}"

# Completion marker: install.sh checks for this, so a run that aborts before
# reaching this line is treated as a hard failure rather than a success.
: > "${TOOLS}/.installTools.done"
echo "[+] installTools.sh completed successfully"
