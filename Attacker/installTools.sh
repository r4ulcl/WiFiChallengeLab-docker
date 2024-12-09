#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Hacking tools
cd
FOLDER=`pwd`
TOOLS=$FOLDER/tools
mkdir $TOOLS

export DEBIAN_FRONTEND="noninteractive"

#echo "deb http://archive.canonical.com/ubuntu focal partner" >> /etc/apt/sources.list
#echo "deb-src http://archive.canonical.com/ubuntu focal partner" >> /etc/apt/sources.list
#echo "deb http://archive.ubuntu.com/ubuntu focal main universe restricted multiverse" >> /etc/apt/sources.list

apt update

# Basic tools
apt install wget curl git -y

# Rockyou and dicts
cd 
curl https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -s -L | head -n 1000000 > ~/rockyou-top100000.txt
wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt

apt upgrade -y

# Nmap
apt install nmap -y

# Python3
apt install -y python3 

# wpa_gui
apt install -y wpagui 

# EAP_buster
cd $TOOLS
git clone https://github.com/blackarrowsec/EAP_buster

# OpenSSL 3 for Ubuntu
apt install build-essential checkinstall zlib1g-dev -y
cd /usr/local/src/
VERSION='openssl-3.2.1'
wget https://www.openssl.org/source/$VERSION.tar.gz
tar -xvf $VERSION.tar.gz > /dev/null
rm $VERSION.tar.gz
cd $VERSION
./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib
source ~/.bashrc
make -j $(nproc)
make install

# Hcxtools
cd $TOOLS
apt install python3-pip sqlitebrowser -y
apt install tshark -y
apt install pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc -y
wget https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/hcxtools_6.0.2-1+b1_amd64.deb
dpkg -i hcxtools_6.0.2-1+b1_amd64.deb
apt --fix-broken install -y
rm -rf hcxtools_6.0.2-1+b1_amd64.deb

# Wifi_db
cd $TOOLS
git clone https://github.com/r4ulcl/wifi_db
cd wifi_db
pip3 install -r requirements.txt 

# PcapFilter.sh
cd $TOOLS
wget https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/78e097e1d4a9eb5f43ab0b2763195c04f02c4998/pcapFilter.sh
chmod +x pcapFilter.sh

# UnicastDeauth
git clone 'https://github.com/mamatb/UnicastDeauth.git'
pip install -r './UnicastDeauth/requirements.txt'

# EapHammer
#!/bin/bash

# Navigate to the tools directory
cd $TOOLS

# Clone the EapHammer repository
git clone https://github.com/r4ulcl/eaphammer.git
cd eaphammer

# Install dependencies listed in kali-dependencies.txt
echo "Installing dependencies from kali-dependencies.txt..."
while read -r dependency; do
  echo "Installing $dependency..."
  apt-get install "$dependency" -y || { echo "Failed to install $dependency. Attempting to fix."; apt --fix-broken install -y; }
done < kali-dependencies.txt

# Install additional packages
echo "Installing additional packages..."
apt-get install dsniff apache2 build-essential libssl-dev libffi-dev python-dev python-openssl python3-openssl -y || apt --fix-broken install -y

# Disable and stop Apache2 service
echo "Disabling Apache2 service..."
systemctl stop apache2
systemctl disable apache2
update-rc.d apache2 disable

# Run EapHammer setup
echo "Running EapHammer setup..."
./ubuntu-unattended-setup || echo "Failed to run ubuntu-unattended-setup."

# Install Python dependencies
echo "Installing Python dependencies..."
python3 -m pip install --upgrade flask || echo "Failed to install Python packages."
python3 -m pip install --upgrade flask_cors || echo "Failed to install Python packages."
python3 -m pip install --upgrade flask_socketio || echo "Failed to install Python packages."
python3 -m pip install --upgrade pywebcopy || echo "Failed to install Python packages."
python3 -m pip install --upgrade pyopenssl || echo "Failed to install Python packages."
python3 -m pip install --upgrade gevent || echo "Failed to install Python packages."
apt-get install python-netifaces -y || apt --fix-broken install -y

echo "EapHammer setup completed successfully!"


wget https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini

# Hostapd-wpe
cd $TOOLS
apt install libsqlite3-dev -y
wget https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/52925bbdd13f739af6fc32e11f589b8c3e6e1fe5/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch
wget https://w1.fi/releases/hostapd-2.11.tar.gz
tar -zxf hostapd-2.11.tar.gz
rm hostapd-2.11.tar.gz
cd hostapd-2.11
patch -p1 < ../hostapd-2.11-wpe.patch
rm ../hostapd-2.11-wpe.patch
cd hostapd
make
make install
make wpe
cd /etc/hostapd-wpe/certs
./bootstrap
make install

# Aircrack
cd $TOOLS
apt install build-essential autoconf automake libtool pkg-config libnl-3-dev libnl-genl-3-dev libssl-dev ethtool shtool rfkill zlib1g-dev libpcap-dev libsqlite3-dev libhwloc-dev libcmocka-dev hostapd wpasupplicant tcpdump screen iw usbutils expect -y
git clone https://github.com/aircrack-ng/aircrack-ng.git
cd aircrack-ng
autoreconf -i
./configure
make
make install
ldconfig
cd $TOOLS
rm -r aircrack-ng

# Hashcat
cd $TOOLS
# Install old version for dependencies
apt install hashcat p7zip -y
wget https://hashcat.net/files/hashcat-6.0.0.7z
p7zip -d hashcat-6.0.0.7z
rm hashcat-6.0.0.7z
wget https://http.kali.org/kali/pool/main/h/hashcat-utils/hashcat-utils_1.9-0kali2_amd64.deb
dpkg -i hashcat-utils_1.9-0kali2_amd64.deb
rm -rf hashcat-utils_1.9-0kali2_amd64.deb

# Delete old version of hashcat to avoid confusion
rm /usr/bin/hashcat > /dev/null 2>&1

ln -s /root/tools/hashcat-6.0.0/hashcat.bin /usr/local/bin/hashcat > /dev/null 2>&1
echo "alias hashcat='sudo hashcat'" >> /home/user/.bashrc

# Creap
cd $TOOLS
git clone https://github.com/Snizz/crEAP

# Arp-scan
apt install arp-scan -y

# Asleap
wget https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
dpkg -i libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
rm -rf libssl1.0.2_1.0.2u-1~deb9u1_amd64.deb
wget https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/asleap_2.2-1parrot0_amd64.deb
dpkg -i asleap_2.2-1parrot0_amd64.deb
rm -rf asleap_2.2-1parrot0_amd64.deb

# Bettercap
apt install golang git build-essential libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev -y

wget https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bettercap_2.28-0kali2_amd64.deb
dpkg -i bettercap_2.28-0kali2_amd64.deb
rm -rf bettercap_2.28-0kali2_amd64.deb

# BeEF
apt install autoconf bison build-essential libssl-dev libyaml-dev libreadline-dev zlib1g-dev libffi-dev libgdbm6 libgdbm-dev libdb-dev ruby-bundler nodejs rbenv -y
cd $HOME
curl -fsSL https://github.com/rbenv/rbenv-installer/raw/HEAD/bin/rbenv-installer | bash
export PATH="$HOME/.rbenv/bin:$PATH"
eval "$(rbenv init -)"
echo 'export PATH="$HOME/.rbenv/bin:$PATH"' >> ~/.bashrc
echo 'eval "$(rbenv init -)"' >> ~/.bashrc
source ~/.bashrc
rbenv install 3.1.4
rbenv global 3.1.4
cd /usr/share/
git clone https://github.com/beefproject/beef.git
cd beef
rbenv local 3.1.4
gem install bundler
bundle install
echo -e '#!/usr/bin/env bash\n\ncd /usr/share/beef\n./beef' > "/usr/local/bin/beef"
chmod +x "/usr/local/bin/beef"

# airgeddon
apt install tshark john lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd -y
apt install ettercap-text-only hcxdumptool mdk3 mdk4 arping ccze -y
systemctl disable lighttpd
systemctl stop lighttpd
cd $TOOLS
git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git
cd airgeddon

# Disable airgeddon auto-update
sed -i '/^AIRGEDDON_AUTO_UPDATE=/c\AIRGEDDON_AUTO_UPDATE=false' .airgeddonrc

# Plugins airgeddon
cd plugins
git clone --depth 1 https://github.com/OscarAkaElvis/airgeddon-plugins.git
cp airgeddon-plugins/allchars_captiveportal/allchars_captiveportal.sh .
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.sh .
cp airgeddon-plugins/wpa3_online_attack/wpa3_online_attack.py .
mkdir wpa_supplicant_binaries
cp airgeddon-plugins/wpa3_online_attack/wpa_supplicant_binaries/wpa_supplicant_amd64 ./wpa_supplicant_binaries/
rm -rf airgeddon-plugins

# Bully
wget https://github.com/v1s1t0r1sh3r3/airgeddon_deb_packages/raw/refs/heads/master/amd64/bully_1.1.+git20190923-0kali1_amd64.deb
dpkg -i bully_1.1.+git20190923-0kali1_amd64.deb
rm -rf bully_1.1.+git20190923-0kali1_amd64.deb

# Hostapd-mana
apt install build-essential git libnl-genl-3-dev libssl-dev build-essential pkg-config git libnl-genl-3-dev libssl-dev -y

cd $TOOLS
git clone https://github.com/sensepost/hostapd-mana
cd hostapd-mana
make -C hostapd -j 4

ln -s /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

# Eapeak
cd $TOOLS
apt install python-dev libssl-dev swig python3-dev gcc -y
pip3 install pipenv
git clone https://github.com/securestate/eapeak
cd eapeak
pipenv --two install

# Reaver
apt install libpcap-dev -y
cd $TOOLS
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x*
cd src
./configure
make
make install

# Wpa_sycophant
cd $TOOLS
git clone https://github.com/sensepost/wpa_sycophant
cd wpa_sycophant/
make -C wpa_supplicant -j 4

# Berate_ap
cd $TOOLS
git clone https://github.com/sensepost/berate_ap

# MDK4
apt install pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev -y
cd $TOOLS
git clone https://github.com/aircrack-ng/mdk4
cd mdk4
make
make install

# Air-Hammer
cd $TOOLS
git clone https://github.com/Wh1t3Rh1n0/air-hammer
cd air-hammer
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
pip2 install -U setuptools 
python2 get-pip.py
pip2 install wpa_supplicant
pip2 install service_identity
 
# Wifipumpkin3
cd $TOOLS
apt install python3-dev libssl-dev libffi-dev build-essential python3 -y
apt install python3-pyqt5 python3-bs4 python3-dnslib python3-dnspython python3-flask-restful python3-isc-dhcp-leases python3-netaddr python3-scapy python3-tabulate python3-termcolor python3-twisted python3-urwid -y
git clone https://github.com/P0cL4bs/wifipumpkin3.git
cd wifipumpkin3
sed -i 's/python3.7/python3/g' makefile
make install

# LN home user 
chown -R user $TOOLS
ln -s $TOOLS /home/user/tools

# NEW
apt install macchanger -y
apt install wireshark-qt -y

# Wacker WPA3 brute force online
cd $TOOLS
git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
apt install -y pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools
cp defconfig wpa_supplicant-2.10/wpa_supplicant/.config
git apply wpa_supplicant.patch
cd wpa_supplicant-2.10/wpa_supplicant
make -j $(nproc)
ls -al wpa_supplicant

# Hcxtools
cd $TOOLS
git clone https://salsa.debian.org/pkg-security-team/hcxtools #For ubuntu 20
cd hcxtools
make 
make install

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

# Enable ssh (if dont use vagrant)
#apt install -y ssh
#echo Port 2222 >> /etc/ssh/sshd_config && systemctl enable ssh
