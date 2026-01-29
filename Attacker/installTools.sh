#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND="noninteractive"
export APT_LISTCHANGES_FRONTEND="none"

. /etc/os-release
DEB_CODENAME="${VERSION_CODENAME:-bookworm}"

APT_GET="apt-get -yq -o Dpkg::Use-Pty=0 -o Dpkg::Options::=--force-confnew"

# -----------------------------------------------------------------------------
# resolv.conf lock during install + guaranteed restore
# -----------------------------------------------------------------------------
set +e
RESOLV_BAK="/root/resolv.conf.pre-install.$(date +%s)"
RESOLV_WAS_LINK=false

if [ -L /etc/resolv.conf ]; then
  RESOLV_WAS_LINK=true
fi

if [ -e /etc/resolv.conf ]; then
  cp -a /etc/resolv.conf "$RESOLV_BAK" || true
fi

restore_resolv() {
  set +e
  chattr -i /etc/resolv.conf 2>/dev/null || true
  if [ -f "$RESOLV_BAK" ]; then
    rm -f /etc/resolv.conf 2>/dev/null || true
    cp -a "$RESOLV_BAK" /etc/resolv.conf || true
    if $RESOLV_WAS_LINK; then
      echo "Warning: /etc/resolv.conf was originally a symlink, restored as a regular file" >&2
    fi
  else
    chattr -i /etc/resolv.conf 2>/dev/null || true
  fi
}
trap restore_resolv EXIT

# Replace symlink with a real file temporarily
if [ -L /etc/resolv.conf ]; then
  rm -f /etc/resolv.conf
fi

cat >/etc/resolv.conf <<'EOF'
nameserver 1.1.1.1
nameserver 8.8.8.8
options timeout:2 attempts:2
EOF

chattr +i /etc/resolv.conf 2>/dev/null || true

getent hosts deb.debian.org >/dev/null 2>&1 || echo "Warning: DNS check failed" >&2
set -e

# -----------------------------------------------------------------------------
# workspace
# -----------------------------------------------------------------------------
cd /root
FOLDER="$(pwd)"
TOOLS="${FOLDER}/tools"
mkdir -p "${TOOLS}"

# -----------------------------------------------------------------------------
# base packages
# -----------------------------------------------------------------------------
$APT_GET update </dev/null
$APT_GET install wget curl git ca-certificates build-essential </dev/null

# basic utilities
$APT_GET install nmap python3 python3-pip wpagui sqlite3 tshark jq p7zip p7zip-full </dev/null

# -----------------------------------------------------------------------------
# Python 2 is mandatory: provide /usr/bin/python2 + pip2, prefer pyenv on bookworm
# -----------------------------------------------------------------------------
ensure_python2() {
  local PYENV_ROOT="/usr/local/pyenv"
  local PY2_VER="2.7.18"
  local PY2_BIN=""
  local PIP2_BIN=""

  if command -v python2 >/dev/null 2>&1; then
    echo "[+] python2 already present"
    return 0
  fi

  echo "[*] python2 not found in PATH. Installing via pyenv..."
  $APT_GET install make gcc libssl-dev zlib1g-dev libbz2-dev libreadline-dev libsqlite3-dev libffi-dev xz-utils tk-dev libncursesw5-dev libgdbm-dev liblzma-dev uuid-dev </dev/null

  if [ ! -d "$PYENV_ROOT" ]; then
    git clone https://github.com/pyenv/pyenv.git "$PYENV_ROOT"
  fi

  export PYENV_ROOT
  export PATH="$PYENV_ROOT/bin:$PATH"

  eval "$(pyenv init -)" >/dev/null 2>&1 || true

  if ! pyenv versions --bare 2>/dev/null | grep -qx "$PY2_VER"; then
    CFLAGS="-O2" pyenv install "$PY2_VER"
  fi

  PY2_BIN="$PYENV_ROOT/versions/$PY2_VER/bin/python2.7"
  PIP2_BIN="$PYENV_ROOT/versions/$PY2_VER/bin/pip2"

  if [ ! -x "$PY2_BIN" ]; then
    echo "Error: pyenv python2 binary not found at $PY2_BIN" >&2
    return 1
  fi

  # Install pip for Python 2 if missing
  if [ ! -x "$PIP2_BIN" ]; then
    echo "[*] Installing pip for Python 2..."
    curl -fsSL https://bootstrap.pypa.io/pip/2.7/get-pip.py -o /tmp/get-pip.py
    "$PY2_BIN" /tmp/get-pip.py
  fi

  # Provide conventional paths expected by legacy tools
  ln -sf "$PY2_BIN" /usr/bin/python2
  ln -sf "$PY2_BIN" /usr/bin/python2.7
  ln -sf "$PY2_BIN" /usr/local/bin/python2

  if [ -x "$PIP2_BIN" ]; then
    ln -sf "$PIP2_BIN" /usr/local/bin/pip2
  fi

  # Alternatives
  update-alternatives --install /usr/bin/python python /usr/bin/python3 10 || true
  update-alternatives --install /usr/bin/python python /usr/bin/python2 20 || true
  update-alternatives --set python /usr/bin/python2 || true

  echo "[+] Python 2 ready: $(/usr/bin/python2 -V 2>&1)"
  /usr/bin/python2 -m pip --version >/dev/null 2>&1 || true
}

ensure_python2

# -----------------------------------------------------------------------------
# wordlists
# -----------------------------------------------------------------------------
cd "${FOLDER}"
curl -fsSL https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt | head -n 1000000 > rockyou-top100000.txt
wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt -O top-usernames-shortlist.txt

# -----------------------------------------------------------------------------
# EAP_buster
# -----------------------------------------------------------------------------
cd "${TOOLS}"
[ ! -d EAP_buster ] && git clone https://github.com/blackarrowsec/EAP_buster

# -----------------------------------------------------------------------------
# OpenSSL local build only if system openssl is not 3.x
# -----------------------------------------------------------------------------
$APT_GET install checkinstall zlib1g-dev </dev/null
cd /usr/local/src
OPENSSL_VER="openssl-3.2.1"
if ! openssl version 2>/dev/null | grep -qE '^OpenSSL 3\.'; then
  if [ ! -d "${OPENSSL_VER}" ]; then
    wget -q https://www.openssl.org/source/${OPENSSL_VER}.tar.gz
    tar xf ${OPENSSL_VER}.tar.gz && rm -f ${OPENSSL_VER}.tar.gz
  fi
  cd ${OPENSSL_VER}
  ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
  make -j"$(nproc)"
  make install
  ln -sf /usr/local/openssl/bin/openssl /usr/local/bin/openssl
fi

# -----------------------------------------------------------------------------
# hcxtools and related packages (use distro packages; avoid old debs needing libssl1.1)
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc </dev/null
$APT_GET install hcxdumptool hcxtools ieee-data </dev/null || true

# -----------------------------------------------------------------------------
# wifi_db
# -----------------------------------------------------------------------------
$APT_GET install sqlitebrowser </dev/null
cd "${TOOLS}"
if [ ! -d wifi_db ]; then
  git clone https://github.com/r4ulcl/wifi_db
  cd wifi_db
  python3 -m pip install --break-system-packages -r requirements.txt || python3 -m pip install -r requirements.txt
fi

# -----------------------------------------------------------------------------
# pcapFilter helper
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install xxd </dev/null
wget -q https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/78e097e1d4a9eb5f43ab0b2763195c04f02c4998/pcapFilter.sh -O pcapFilter.sh
chmod +x pcapFilter.sh

# -----------------------------------------------------------------------------
# UnicastDeauth
# -----------------------------------------------------------------------------
cd "${TOOLS}"
git clone https://github.com/mamatb/UnicastDeauth.git || true
python3 -m pip install --break-system-packages -r UnicastDeauth/requirements.txt || python3 -m pip install -r UnicastDeauth/requirements.txt

# -----------------------------------------------------------------------------
# eaphammer fork
# -----------------------------------------------------------------------------
cd "${TOOLS}"
if [ ! -d eaphammer ]; then
  git clone https://github.com/r4ulcl/eaphammer.git
  cd eaphammer
  while read -r dep; do
    [ -z "$dep" ] && continue
    $APT_GET install "$dep" </dev/null || $APT_GET -f install </dev/null || true
  done < kali-dependencies.txt

  $APT_GET install dsniff apache2 libffi-dev python3-openssl </dev/null
  systemctl disable --now apache2 >/dev/null 2>&1 || true

  ./ubuntu-unattended-setup || echo "eaphammer unattended setup failed, continuing" >&2

  python3 -m pip install --break-system-packages --upgrade flask flask_cors flask_socketio pywebcopy pyopenssl gevent netifaces || true
  wget -q https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini || true
fi

ln -sf /usr/bin/python3 /usr/bin/python3.8 || true
python3 -m pip install --break-system-packages aioquic || true
pip3 install --break-system-packages tqdm pem aioquic || true
python3 -m pip install --break-system-packages -r /root/tools/eaphammer/pip.req || true

# -----------------------------------------------------------------------------
# hostapd-wpe 2.11
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install libsqlite3-dev </dev/null
if [ ! -d hostapd-2.11 ]; then
  wget -q https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/52925bbd/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch -O hostapd-2.11-wpe.patch
  wget -q https://w1.fi/releases/hostapd-2.11.tar.gz
  tar zxf hostapd-2.11.tar.gz && rm -f hostapd-2.11.tar.gz
  cd hostapd-2.11
  patch -p1 < ../hostapd-2.11-wpe.patch && rm -f ../hostapd-2.11-wpe.patch
  cd hostapd
  make -j"$(nproc)"
  make install
  make wpe || true
  cd /etc/hostapd-wpe/certs && ./bootstrap && make install || true
fi

# -----------------------------------------------------------------------------
# Aircrack-ng from source
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install autoconf automake libtool libnl-3-dev libnl-genl-3-dev libpcap-dev libhwloc-dev libcmocka-dev hostapd wpasupplicant tcpdump screen iw usbutils expect rfkill ethtool shtool pkg-config libssl-dev </dev/null

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

# -----------------------------------------------------------------------------
# Hashcat and utils
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install hashcat </dev/null
if [ ! -d hashcat-6.0.0 ]; then
  wget -q https://hashcat.net/files/hashcat-6.0.0.7z -O hashcat-6.0.0.7z
  7z x hashcat-6.0.0.7z && rm -f hashcat-6.0.0.7z

  wget -q https://http.kali.org/kali/pool/main/h/hashcat-utils/hashcat-utils_1.9-0kali2_amd64.deb -O hashcat-utils.deb || true
  dpkg -i hashcat-utils.deb || $APT_GET -f install </dev/null || true
  rm -f hashcat-utils.deb

  ln -sf /root/tools/hashcat-6.0.0/hashcat.bin /usr/local/bin/hashcat || true
  if id user >/dev/null 2>&1 && [ -d /home/user ]; then
    echo "alias hashcat='sudo hashcat'" >> /home/user/.bashrc
  fi
fi
timeout 60s /usr/local/bin/hashcat -b || true

# -----------------------------------------------------------------------------
# John the Ripper
# -----------------------------------------------------------------------------
cd "${TOOLS}"
$APT_GET install yasm pkg-config libgmp-dev libbz2-dev </dev/null
git clone https://github.com/openwall/john.git || true
cd john/src
./configure || true
make -s clean || true
make -sj"$(nproc)" || true

# -----------------------------------------------------------------------------
# Misc Wi-Fi tools
# -----------------------------------------------------------------------------
cd "${TOOLS}"
[ ! -d crEAP ] && git clone https://github.com/Snizz/crEAP
$APT_GET install arp-scan </dev/null

# legacy debs can be flaky on Debian; keep best-effort and do not break the system
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb -O libssl1.0.2.deb || true
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/asleap_2.2-1parrot0_amd64.deb -O asleap.deb || true
dpkg -i libssl1.0.2.deb asleap.deb || $APT_GET -f install </dev/null || true
rm -f libssl1.0.2.deb asleap.deb

# Bettercap
$APT_GET install golang libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev </dev/null
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bettercap_2.28-0kali2_amd64.deb -O bettercap.deb || true
dpkg -i bettercap.deb || $APT_GET -f install </dev/null || true
rm -f bettercap.deb

# BeEF
$APT_GET install autoconf bison libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev libgdbm-dev libdb-dev ruby-bundler nodejs </dev/null
if [ ! -d /usr/local/rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv
fi
export PATH="/usr/local/rbenv/bin:$PATH"
eval "$(/usr/local/rbenv/bin/rbenv init - bash)" >/dev/null 2>&1 || true
/usr/local/rbenv/bin/rbenv install -s 3.1.4 || true
/usr/local/rbenv/bin/rbenv global 3.1.4 || true
if [ ! -d /usr/share/beef ]; then
  git clone https://github.com/beefproject/beef.git /usr/share/beef
fi
cd /usr/share/beef
/usr/local/rbenv/bin/rbenv local 3.1.4 || true
gem install bundler || true
bundle install || true
install -m755 <(printf '#!/usr/bin/env bash\ncd /usr/share/beef && ./beef\n') /usr/local/bin/beef || true

# airgeddon
$APT_GET install lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd ettercap-text-only hcxdumptool mdk3 mdk4 arping ccze </dev/null
systemctl disable --now lighttpd >/dev/null 2>&1 || true
cd "${TOOLS}"
[ ! -d airgeddon ] && git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git
cd airgeddon
sed -i '/^AIRGEDDON_AUTO_UPDATE=/c\AIRGEDDON_AUTO_UPDATE=false' .airgeddonrc || true
sed -i '/^AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=/c\AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=false' .airgeddonrc || true
cd plugins
[ ! -d airgeddon-plugins ] && git clone --depth 1 https://github.com/OscarAkaElvis/airgeddon-plugins.git
cp airgeddon-plugins/allchars_captiveportal/allchars_captiveportal.sh . || true
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.sh . || true
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.py . || true
mkdir -p wpa_supplicant_binaries
cp airgeddon-plugins/wpa3_online_attack/wpa_supplicant_binaries/wpa_supplicant_amd64 ./wpa_supplicant_binaries/ || true
rm -rf airgeddon-plugins
git clone --depth 1 https://github.com/Janek79ax/dragon-drain-wpa3-airgeddon-plugin.git || true
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain.sh . || true
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain_attack.py . || true
rm -rf dragon-drain-wpa3-airgeddon-plugin
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bully_1.1.+git20190923-0kali1_amd64.deb -O bully.deb || true
dpkg -i bully.deb || $APT_GET -f install </dev/null || true
rm -f bully.deb

# hostapd-mana
$APT_GET install libnl-genl-3-dev libssl-dev </dev/null
cd "${TOOLS}"
[ ! -d hostapd-mana ] && git clone https://github.com/sensepost/hostapd-mana
cd hostapd-mana && make -C hostapd -j"$(nproc)"
ln -sf /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

# eapeak
cd "${TOOLS}"
$APT_GET install swig python3-dev </dev/null
python3 -m pip install --break-system-packages pipenv || python3 -m pip install pipenv
if [ ! -d eapeak ]; then
  git clone https://github.com/securestate/eapeak
  cd eapeak
  if command -v python2 >/dev/null 2>&1; then
    pipenv --two install || echo "pipenv on Python 2 failed, continuing" >&2
  else
    echo "python2 not available, skipping pipenv --two for eapeak" >&2
  fi
fi

# reaver fork
$APT_GET install libpcap-dev </dev/null
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

# OpenSSL legacy provider enable (only if OpenSSL 3 config exists)
CONF_DIR="$(openssl version -d 2>/dev/null | awk -F'"' '{print $2}')"
OPENSSL_CNF="$CONF_DIR/openssl.cnf"
if [ -n "$CONF_DIR" ] && [ -f "$OPENSSL_CNF" ] && ! grep -q "\[legacy_sect\]" "$OPENSSL_CNF"; then
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
$APT_GET install pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev </dev/null
cd "${TOOLS}"
[ ! -d mdk4 ] && git clone https://github.com/aircrack-ng/mdk4
cd mdk4 && make -j"$(nproc)" && make install

# air-hammer (Python 2)
cd "${TOOLS}"
[ ! -d air-hammer ] && git clone https://github.com/Wh1t3Rh1n0/air-hammer
cd air-hammer
if command -v python2 >/dev/null 2>&1; then
  curl -fsSL https://bootstrap.pypa.io/pip/2.7/get-pip.py -o /tmp/get-pip.py
  python2 /tmp/get-pip.py || true
  python2 -m pip install -U setuptools wpa_supplicant service_identity || true
fi

# Wifipumpkin3
$APT_GET install python3-dev libssl-dev libffi-dev build-essential python3-pyqt5 python3-bs4 python3-dnslib python3-dnspython python3-flask-restful python3-isc-dhcp-leases python3-netaddr python3-scapy python3-tabulate python3-termcolor python3-twisted python3-urwid </dev/null
cd "${TOOLS}"
[ ! -d wifipumpkin3 ] && git clone https://github.com/P0cL4bs/wifipumpkin3.git
cd wifipumpkin3 && sed -i 's/python3\.7/python3/g' makefile && make install || true

# convenience
if id user >/dev/null 2>&1 && [ -d /home/user ]; then
  chown -R user:user "${TOOLS}" || true
  ln -sf "${TOOLS}" /home/user/tools || true
fi
$APT_GET install macchanger wireshark-qt </dev/null

# Wacker
cd "${TOOLS}"
[ ! -d wacker ] && git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
$APT_GET install pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools </dev/null
cp defconfig wpa_supplicant-2.10/wpa_supplicant/.config
git apply wpa_supplicant.patch || true
cd wpa_supplicant-2.10/wpa_supplicant && make -j"$(nproc)" || true

# hcxtools from source refresh
cd "${TOOLS}"
[ ! -d hcxtools-src ] && git clone https://salsa.debian.org/pkg-security-team/hcxtools hcxtools-src
cd hcxtools-src && make -j"$(nproc)" && make install || true

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
python3 -m pip install --break-system-packages pycryptodome || true
bzip2 -d assless-chaps/10-million-password-list-top-1000000.db.bz2 || true

# dragondrain
cd "${TOOLS}"
git clone https://github.com/vanhoefm/dragondrain-and-time || true
$APT_GET update </dev/null
$APT_GET install autoconf automake libtool shtool libssl-dev pkg-config </dev/null
cd dragondrain-and-time
make distclean 2>/dev/null || true
CFLAGS='-D__packed="__attribute__((__packed__))"' ./configure
make


###############################################################################
# Optional: enable SSH on port 2222 (commented out by default)
###############################################################################
# apt-get install -y ssh
# echo 'Port 2222' >> /etc/ssh/sshd_config && systemctl enable --now ssh


echo -e "\n[+] Wireless assessment toolkit installed under ${TOOLS}"
