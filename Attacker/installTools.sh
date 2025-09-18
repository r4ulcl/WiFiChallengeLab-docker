#!/usr/bin/env bash
#set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "Please run as root" >&2
  exit 1
fi

###############################################################################
# Prep and convenience variables
###############################################################################

export DEBIAN_FRONTEND="noninteractive"

cd ~
FOLDER="$(pwd)"
TOOLS="${FOLDER}/tools"
mkdir -p "${TOOLS}"

###############################################################################
# System update and basic utilities
###############################################################################

apt-get install -y wget curl git

###############################################################################
# Wordlists – top 1 M rockyou and username shortlist
###############################################################################

cd "${FOLDER}"
curl -sSL https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt | \
  head -n 1000000 > rockyou-top100000.txt
wget -q https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt

###############################################################################
# Core packages
###############################################################################

apt-get install -y nmap python3 python3-pip wpagui
# Python 2 stack (needed by several legacy tools)
apt-get install -y python2 python2-dev

# Set python to python2 to old tools
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 1
sudo update-alternatives --set python /usr/bin/python2

###############################################################################
# EAP_buster
###############################################################################

cd "${TOOLS}"
if [ ! -d EAP_buster ]; then
  git clone https://github.com/blackarrowsec/EAP_buster
fi

###############################################################################
# Build OpenSSL 3.x locally (if the distro version is insufficient)
###############################################################################

apt-get install -y build-essential checkinstall zlib1g-dev
cd /usr/local/src
OPENSSL_VER="openssl-3.2.1"
if [ ! -d "${OPENSSL_VER}" ]; then
  wget -q https://www.openssl.org/source/${OPENSSL_VER}.tar.gz
  tar xf ${OPENSSL_VER}.tar.gz && rm ${OPENSSL_VER}.tar.gz
  cd ${OPENSSL_VER}
  ./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
  make -j "$(nproc)" && make install
fi

###############################################################################
# hcxtools (binary .deb + deps)
###############################################################################

cd "${TOOLS}"
apt-get install -y python3-pip sqlitebrowser tshark \
  pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc
if [ ! -f hcxtools_6.0.2-1+b1_amd64.deb ]; then
  wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/hcxtools_6.0.2-1+b1_amd64.deb
  dpkg -i hcxtools_6.0.2-1+b1_amd64.deb || apt-get -y --fix-broken install
  rm hcxtools_6.0.2-1+b1_amd64.deb
fi

###############################################################################
# wifi_db + requirements
###############################################################################

cd "${TOOLS}"
if [ ! -d wifi_db ]; then
  git clone https://github.com/r4ulcl/wifi_db
  cd wifi_db
  pip3 install --break-system-packages -r requirements.txt
  pip3 install -r requirements.txt
fi

###############################################################################
# pcapFilter helper script
###############################################################################

cd "${TOOLS}"
wget -q https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/78e097e1d4a9eb5f43ab0b2763195c04f02c4998/pcapFilter.sh -O pcapFilter.sh
chmod +x pcapFilter.sh

###############################################################################
# UnicastDeauth
###############################################################################

cd "${TOOLS}"
git clone https://github.com/mamatb/UnicastDeauth.git || true
pip3 install --break-system-packages -r UnicastDeauth/requirements.txt

###############################################################################
# EapHammer (fork)
###############################################################################

cd "${TOOLS}"
if [ ! -d eaphammer ]; then
  git clone https://github.com/r4ulcl/eaphammer.git
  cd eaphammer
  echo "Installing apt dependencies…"
  while read -r dep; do
    apt-get install -y "$dep" || apt-get -y --fix-broken install
  done < kali-dependencies.txt
  apt-get install -y dsniff apache2 build-essential libssl-dev libffi-dev python3-openssl
  systemctl disable --now apache2
  ./ubuntu-unattended-setup || echo "eaphammer unattended setup failed – continuing"
  python3 -m pip install --break-system-packages --upgrade flask flask_cors flask_socketio pywebcopy pyopenssl gevent netifaces
  wget -q https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini
fi
sudo ln -sf /usr/bin/python3 /usr/bin/python3.8
pip3 install aioquic

###############################################################################
# Hostapd‑wpe (patched 2.11)
###############################################################################

cd "${TOOLS}"
apt-get install -y libsqlite3-dev
if [ ! -d hostapd-2.11 ]; then
  wget -q https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/52925bbd/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch
  wget -q https://w1.fi/releases/hostapd-2.11.tar.gz
  tar zxf hostapd-2.11.tar.gz && rm hostapd-2.11.tar.gz
  cd hostapd-2.11
  patch -p1 < ../hostapd-2.11-wpe.patch && rm ../hostapd-2.11-wpe.patch
  cd hostapd
  make
  make install
  make wpe
  cd /etc/hostapd-wpe/certs && ./bootstrap && make install
fi

###############################################################################
# Aircrack‑NG build from source (latest master)
###############################################################################

cd "${TOOLS}"
apt-get install -y build-essential autoconf automake libtool pkg-config \
  libnl-3-dev libnl-genl-3-dev libssl-dev ethtool shtool rfkill zlib1g-dev \
  libpcap-dev libsqlite3-dev libhwloc-dev libcmocka-dev hostapd wpasupplicant \
  tcpdump screen iw usbutils expect
if [ ! -d aircrack-ng ]; then
  git clone https://github.com/aircrack-ng/aircrack-ng.git
  cd aircrack-ng
  autoreconf -i
  ./configure
  make -j "$(nproc)"
  make install
  ldconfig
  cd .. && rm -rf aircrack-ng
fi

###############################################################################
# Hashcat 6.0.0 + utils
###############################################################################

cd "${TOOLS}"
apt-get install -y hashcat p7zip-full
if [ ! -d hashcat-6.0.0 ]; then
  wget -q https://hashcat.net/files/hashcat-6.0.0.7z
  7zr x hashcat-6.0.0.7z && rm hashcat-6.0.0.7z
  wget -q https://http.kali.org/kali/pool/main/h/hashcat-utils/hashcat-utils_1.9-0kali2_amd64.deb
  dpkg -i hashcat-utils_1.9-0kali2_amd64.deb && rm hashcat-utils_1.9-0kali2_amd64.deb
  ln -sf /root/tools/hashcat-6.0.0/hashcat.bin /usr/local/bin/hashcat
  echo "alias hashcat='sudo hashcat'" >> /home/user/.bashrc
fi

timeout 120s /usr/local/bin/hashcat -b

###############################################################################
# John
###############################################################################

cd "${TOOLS}"
sudo apt-get -y install git build-essential libssl-dev zlib1g-dev yasm pkg-config libgmp-dev libpcap-dev libbz2-dev 
git clone https://github.com/openwall/john.git
cd john/src
./configure && make -s clean && make -sj4
sudo make install


###############################################################################
# Misc Wi‑Fi / RF assessment utilities (creAP, airgeddon, etc.)
###############################################################################

cd "${TOOLS}"
# Creap
[ ! -d crEAP ] && git clone https://github.com/Snizz/crEAP
# arp-scan
apt-get install -y arp-scan
# asleap & libssl1.0.2 debs (may fail on Noble but left intact for parity)
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/asleap_2.2-1parrot0_amd64.deb
(dpkg -i libssl1.0.2_*.deb asleap_*.deb || apt-get -y --fix-broken install) && rm libssl1.0.2_*.deb asleap_*.deb

###############################################################################
# Bettercap, BeEF, airgeddon and more … (unchanged, just ensured python2‑dev)
###############################################################################
# NOTE:  Full command blocks retained from the original script.  They work
# unmodified on 24.04, so they’re included verbatim below.

# Bettercap
apt-get install -y golang build-essential libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bettercap_2.28-0kali2_amd64.deb
(dpkg -i bettercap_*.deb || apt-get -y --fix-broken install) && rm bettercap_*.deb

# BeEF
apt-get install -y autoconf bison build-essential libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev ruby-bundler nodejs rbenv
cd "${FOLDER}"
if [ ! -d ~/.rbenv ]; then
  curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
fi
export PATH="$HOME/.rbenv/bin:$PATH"
if ! command -v rbenv >/dev/null; then
  echo "rbenv not found in PATH – aborting BeEF install" >&2
else
  eval "$(rbenv init -)"
  rbenv install -s 3.1.4
  rbenv global 3.1.4
  cd /usr/share
  [ ! -d beef ] && git clone https://github.com/beefproject/beef.git
  cd beef
  rbenv local 3.1.4
  gem install bundler
  bundle install
  install -m755 <(printf '#!/usr/bin/env bash\ncd /usr/share/beef && ./beef\n') /usr/local/bin/beef
fi

# airgeddon
apt-get install -y tshark john lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd ettercap-text-only hcxdumptool mdk3 mdk4 arping ccze
systemctl disable --now lighttpd
cd "${TOOLS}"
[ ! -d airgeddon ] && git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git
cd airgeddon

# Disable airgeddon auto-update
sed -i '/^AIRGEDDON_AUTO_UPDATE=/c\AIRGEDDON_AUTO_UPDATE=false' .airgeddonrc
sed -i '/^AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=/c\AIRGEDDON_EVIL_TWIN_ESSID_STRIPPING=false' .airgeddonrc

# Plugins airgeddon
cd plugins
git clone --depth 1 https://github.com/OscarAkaElvis/airgeddon-plugins.git
cp airgeddon-plugins/allchars_captiveportal/allchars_captiveportal.sh .
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.sh .
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.py .
mkdir wpa_supplicant_binaries
cp airgeddon-plugins/wpa3_online_attack/wpa_supplicant_binaries/wpa_supplicant_amd64 ./wpa_supplicant_binaries/
rm -rf airgeddon-plugins

git clone --depth 1 https://github.com/Janek79ax/dragon-drain-wpa3-airgeddon-plugin.git
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain.sh .
cp dragon-drain-wpa3-airgeddon-plugin/wpa3_dragon_drain_attack.py .
rm -rf dragon-drain-wpa3-airgeddon-plugin

# Bully
wget -q https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bully_1.1.+git20190923-0kali1_amd64.deb
(dpkg -i bully_*.deb || apt-get -y --fix-broken install) && rm bully_*.deb

###############################################################################
# Hostapd‑mana build
###############################################################################

apt-get install -y build-essential libnl-genl-3-dev libssl-dev
cd "${TOOLS}"
if [ ! -d hostapd-mana ]; then
  git clone https://github.com/sensepost/hostapd-mana
  cd hostapd-mana
  make -C hostapd -j "$(nproc)"
  ln -sf /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana
fi

###############################################################################
# eapeak (Python 2 – uses pipenv --two)
###############################################################################

cd "${TOOLS}"
apt-get install -y python2-dev libssl-dev swig python3-dev gcc
pip3 install --break-system-packages pipenv
if [ ! -d eapeak ]; then
  git clone https://github.com/securestate/eapeak
  cd eapeak
  pipenv --two install || echo "pipenv on Python 2 failed – continuing"
fi

###############################################################################
# Reaver WPS fork
###############################################################################

apt-get install -y libpcap-dev
cd "${TOOLS}"
if [ ! -d reaver-wps-fork-t6x ]; then
  git clone https://github.com/t6x/reaver-wps-fork-t6x
  cd reaver-wps-fork-t6x*/src
  ./configure && make -j "$(nproc)" && make install
fi

###############################################################################
# SensePost tools: wpa_sycophant, berate_ap
###############################################################################

cd "${TOOLS}"
[ ! -d wpa_sycophant ] && git clone https://github.com/sensepost/wpa_sycophant
cd wpa_sycophant && make -C wpa_supplicant -j "$(nproc)"

cd "${TOOLS}"
[ ! -d "${TOOLS}/berate_ap" ] && git clone https://github.com/sensepost/berate_ap

# Find OpenSSL config directory
CONF_DIR=$(openssl version -d | awk -F'"' '{print $2}')
OPENSSL_CNF="$CONF_DIR/openssl.cnf"

if [[ ! -f "$OPENSSL_CNF" ]]; then
    echo "OpenSSL config not found at $OPENSSL_CNF"
    echo "Please locate it manually (e.g., /etc/pki/tls/openssl.cnf)"
    exit 1
fi

BACKUP="$OPENSSL_CNF.bak.$(date +%s)"

# Backup the original
cp "$OPENSSL_CNF" "$BACKUP"

# Append legacy provider if missing
if grep -q "\[legacy_sect\]" "$OPENSSL_CNF"; then
    echo "Legacy provider already enabled in $OPENSSL_CNF"
else
    cat <<'EOF' >> "$OPENSSL_CNF"

# Added to enable OpenSSL 3 legacy provider (needed for PEAP-MSCHAPv2)
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
    echo "Legacy provider enabled. Backup saved to $BACKUP"
fi


###############################################################################
# mdk4
###############################################################################

apt-get install -y pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev
cd "${TOOLS}"
[ ! -d mdk4 ] && git clone https://github.com/aircrack-ng/mdk4
cd mdk4 && make -j "$(nproc)" && make install

###############################################################################
# air-hammer (Python 2)
###############################################################################

cd "${TOOLS}"
[ ! -d air-hammer ] && git clone https://github.com/Wh1t3Rh1n0/air-hammer
cd air-hammer
curl -sS https://bootstrap.pypa.io/pip/2.7/get-pip.py -o get-pip.py
python2 get-pip.py
pip2 install -U setuptools wpa_supplicant service_identity

###############################################################################
# Wifipumpkin3
###############################################################################

apt-get install -y python3-dev libssl-dev libffi-dev build-essential \
  python3-pyqt5 python3-bs4 python3-dnslib python3-dnspython python3-flask-restful \
  python3-isc-dhcp-leases python3-netaddr python3-scapy python3-tabulate \
  python3-termcolor python3-twisted python3-urwid
cd "${TOOLS}"
[ ! -d wifipumpkin3 ] && git clone https://github.com/P0cL4bs/wifipumpkin3.git
cd wifipumpkin3 && sed -i 's/python3.7/python3/g' makefile && make install

###############################################################################
# Convenience symlink for normal user & misc extras
###############################################################################

chown -R user:user "${TOOLS}"
ln -sf "${TOOLS}" /home/user/tools
apt-get install -y macchanger wireshark-qt

###############################################################################
# Wacker (WPA3 brute force online PoC)
###############################################################################

cd "${TOOLS}"
[ ! -d wacker ] && git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
apt-get install -y pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools
cp defconfig wpa_supplicant-2.10/wpa_supplicant/.config
git apply wpa_supplicant.patch || true
cd wpa_supplicant-2.10/wpa_supplicant && make -j "$(nproc)"

###############################################################################
# hcxtools (source build for Noble)
###############################################################################

cd "${TOOLS}"
[ ! -d hcxtools-src ] && git clone https://salsa.debian.org/pkg-security-team/hcxtools hcxtools-src
cd hcxtools-src && make -j "$(nproc)" && make install

# Wifiphisher
cd $TOOLS
git clone https://github.com/wifiphisher/extra-phishing-pages
git clone https://github.com/wifiphisher/wifiphisher.git # Download the latest revision
cd wifiphisher
python3 setup.py install

# Wifite2
cd $TOOLS
git clone https://github.com/derv82/wifite2.git
cd wifite2
python3 setup.py install

# assless-chaps
cd $TOOLS
git clone https://github.com/sensepost/assless-chaps
python3 -m pip install pycryptodome
bzip2 -d  assless-chaps/10-million-password-list-top-1000000.db.bz2

###############################################################################
# Optional: enable SSH on port 2222 (commented out by default)
###############################################################################
# apt-get install -y ssh
# echo 'Port 2222' >> /etc/ssh/sshd_config && systemctl enable --now ssh

###############################################################################
# Done!
###############################################################################

echo -e "\n[+] Wireless assessment toolkit installed under ${TOOLS}"