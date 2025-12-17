#!/usr/bin/env bash
#set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root" >&2
  exit 1
fi

export DEBIAN_FRONTEND="noninteractive"
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

# Make it immutable so nothing flips it to 127.0.0.1 mid-install
chattr +i /etc/resolv.conf 2>/dev/null || true

# quick sanity check
getent hosts deb.debian.org >/dev/null || echo "Warning: DNS check failed"
set -e


cd ~
FOLDER="$(pwd)"
TOOLS="${FOLDER}/tools"
mkdir -p "${TOOLS}"

apt-get update
apt-get install -y wget curl git ca-certificates build-essential

# ---------- basic utilities ---------------------------------------------------
apt-get install -y nmap python3 python3-pip wpagui sqlite3 tshark jq p7zip-full

# ---------- Python 2 availability check --------------------------------------
have_py2_pkg=false
if apt-cache show python2 >/dev/null 2>&1; then
  apt-get install -y python2 python2-dev || true
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
  pyenv global 2.7.18 || true
  ln -sf "$(pyenv root)/versions/2.7.18/bin/python" /usr/local/bin/python2 || true
  ln -sf "$(pyenv root)/versions/2.7.18/bin/pip" /usr/local/bin/pip2 || true
fi

# Default python alternative for legacy tools that expect python -> python2
if command -v python2 >/dev/null 2>&1; then
  update-alternatives --install /usr/bin/python python /usr/bin/python2 1 || true
  update-alternatives --set python /usr/bin/python2 || true
fi

# ---------- wordlists ---------------------------------------------------------
cd "${FOLDER}"
curl -sSL https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt | head -n 1000000 > rockyou-top100000.txt
wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt

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

# ---------- hcxtools via deb, then source refresh ----------------------------
cd "${TOOLS}"
apt-get install -y pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc
if [ ! -f hcxtools_6.0.2-1+b1_amd64.deb ]; then
  wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/hcxtools_6.0.2-1+b1_amd64.deb || true
  dpkg -i hcxtools_6.0.2-1+b1_amd64.deb || apt-get -y --fix-broken install || true
  rm -f hcxtools_6.0.2-1+b1_amd64.deb
fi

# ---------- wifi_db -----------------------------------------------------------
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
wget -q https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/78e097e1d4a9eb5f43ab0b2763195c04f02c4998/pcapFilter.sh -O pcapFilter.sh
chmod +x pcapFilter.sh

# ---------- UnicastDeauth -----------------------------------------------------
cd "${TOOLS}"
git clone https://github.com/mamatb/UnicastDeauth.git || true
python3 -m pip install --break-system-packages -r UnicastDeauth/requirements.txt || python3 -m pip install -r UnicastDeauth/requirements.txt

# ---------- EapHammer fork ----------------------------------------------------
cd "${TOOLS}"
if [ ! -d eaphammer ]; then
  git clone https://github.com/r4ulcl/eaphammer.git
  cd eaphammer
  while read -r dep; do
    apt-get install -y "$dep" || apt-get -y --fix-broken install || true
  done < kali-dependencies.txt
  apt-get install -y dsniff apache2 libffi-dev python3-openssl
  systemctl disable --now apache2 || true
  ./ubuntu-unattended-setup || echo "eaphammer unattended setup failed, continuing"
  python3 -m pip install --break-system-packages --upgrade flask flask_cors flask_socketio pywebcopy pyopenssl gevent netifaces || true
  wget -q https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini || true
fi
ln -sf /usr/bin/python3 /usr/bin/python3.8 || true
python3 -m pip install aioquic || true
pip3 install tqdm pem aioquic --break-system-packages || true
python3 -m pip install --break-system-packages -r pip.req

# ---------- hostapd-wpe 2.11 -------------------------------------------------
cd "${TOOLS}"
apt-get install -y libsqlite3-dev
if [ ! -d hostapd-2.11 ]; then
  wget -q https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/52925bbd/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch
  wget -q https://w1.fi/releases/hostapd-2.11.tar.gz
  tar zxf hostapd-2.11.tar.gz && rm hostapd-2.11.tar.gz
  cd hostapd-2.11
  patch -p1 < ../hostapd-2.11-wpe.patch && rm ../hostapd-2.11-wpe.patch
  cd hostapd
  make -j"$(nproc)"
  make install
  make wpe || true
  cd /etc/hostapd-wpe/certs && ./bootstrap && make install || true
fi

# ---------- Aircrack-ng from source ------------------------------------------
cd "${TOOLS}"
apt-get install -y autoconf automake libtool libnl-3-dev libnl-genl-3-dev libpcap-dev libhwloc-dev libcmocka-dev hostapd wpasupplicant tcpdump screen iw usbutils expect rfkill ethtool shtool
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
  dpkg -i hashcat-utils_*.deb || apt-get -y --fix-broken install || true
  rm -f hashcat-utils_*.deb
  ln -sf /root/tools/hashcat-6.0.0/hashcat.bin /usr/local/bin/hashcat || true
  echo "alias hashcat='sudo hashcat'" >> /home/user/.bashrc
fi
timeout 60s /usr/local/bin/hashcat -b || true

# ---------- John the Ripper ---------------------------------------------------
cd "${TOOLS}"
apt-get -y install yasm pkg-config libgmp-dev libbz2-dev
git clone https://github.com/openwall/john.git || true
cd john/src
./configure || true
make -s clean || true
make -sj"$(nproc)" || true
#make install || true

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
if [ ! -d /usr/local/rbenv ]; then
  git clone https://github.com/rbenv/rbenv.git /usr/local/rbenv
fi
export PATH="/usr/local/rbenv/bin:$PATH"
eval "$(/usr/local/rbenv/bin/rbenv init - bash)" || true
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
apt-get install -y lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd ettercap-text-only hcxdumptool mdk3 mdk4 arping ccze
systemctl disable --now lighttpd || true
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
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bully_1.1.+git20190923-0kali1_amd64.deb || true
dpkg -i bully_*.deb || apt-get -y --fix-broken install || true
rm -f bully_*.deb

# hostapd-mana
apt-get install -y libnl-genl-3-dev libssl-dev
cd "${TOOLS}"
[ ! -d hostapd-mana ] && git clone https://github.com/sensepost/hostapd-mana
cd hostapd-mana && make -C hostapd -j"$(nproc)"
ln -sf /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

# eapeak with python2 if present
cd "${TOOLS}"
apt-get install -y swig python3-dev
python3 -m pip install --break-system-packages pipenv || python3 -m pip install pipenv
if [ ! -d eapeak ]; then
  git clone https://github.com/securestate/eapeak
  cd eapeak
  if command -v python2 >/dev/null 2>&1; then
    pipenv --two install || echo "pipenv on Python 2 failed, continuing"
  else
    echo "python2 not available, skipping pipenv --two for eapeak"
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
cd mdk4 && make -j"$(nproc)" && make install

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
cd wifipumpkin3 && sed -i 's/python3.7/python3/g' makefile && make install || true

# convenience
chown -R user:user "${TOOLS}"
ln -sf "${TOOLS}" /home/user/tools || true
apt-get install -y macchanger wireshark-qt

# Wacker
cd "${TOOLS}"
[ ! -d wacker ] && git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
apt-get install -y pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools
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
python3 -m pip install pycryptodome || true
bzip2 -d assless-chaps/10-million-password-list-top-1000000.db.bz2 || true


# dragondrain
cd "${TOOLS}"
git clone  https://github.com/vanhoefm/dragondrain-and-time
apt-get update
apt-get install autoconf automake libtool shtool libssl-dev pkg-config -y

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
