#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

# Rockyou
cd 
curl https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt -s -L | head -n 1000000 > ~/rockyou-top100000.txt
#wget https://github.com/brannondorsey/naive-hashcat/releases/download/data/rockyou.txt
wget https://raw.githubusercontent.com/danielmiessler/SecLists/master/Usernames/top-usernames-shortlist.txt


# Hacking tools
FOLDER=`pwd`
TOOLS=$FOLDER/tools
mkdir $TOOLS

#kali repo
#echo 'deb http://http.kali.org/kali kali-rolling main contrib non-free
#deb http://old.kali.org/kali moto main non-free contrib
#' >> /etc/apt/sources.list.d/kali.list
#gpg --keyserver hkp://keys.gnupg.net --recv-key ED444FF07D8D0BF6
#gpg -a --export ED444FF07D8D0BF6 | sudo apt-key add -
#sudo apt update

sudo apt-get install nmap -y

# Python
sudo apt-get install -y python3 


# EAP_buster
cd $TOOLS
git clone https://github.com/blackarrowsec/EAP_buster

# OpenSSL 3 for ubuntu
sudo apt-get install build-essential checkinstall zlib1g-dev -y
cd /usr/local/src/
wget https://www.openssl.org/source/openssl-3.0.2.tar.gz
sudo tar -xvf openssl-3.0.2.tar.gz
rm openssl-3.0.2.tar.gz
cd openssl-3.0.2
./config --prefix=/usr/local/ssl --openssldir=/usr/local/ssl shared zlib
make
make test
make install

#wifi_db
cd $TOOLS
sudo apt-get install python3-pip sqlitebrowser -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install tshark -y
git clone https://github.com/RaulCalvoLaorden/wifi_db
cd wifi_db
pip3 install -r requirements.txt 

# pcapFilter.sh
cd $TOOLS
wget https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/a22ac3095e197dc97745d36ece49bb455fc6d1ae/pcapFilter.sh
chmod +x pcapFilter.sh

#Eaphhammer
cd $TOOLS
git clone https://github.com/r4ulcl/eaphammer.git
cd eaphammer
for L in `cat kali-dependencies.txt` ; do echo $L; apt-get install $L -y ;done
sudo apt-get install dsniff apache2 -y
sudo systemctl stop apache2
sudo systemctl disable apache2
sudo update-rc.d apache2 disable
sudo apt-get install build-essential libssl-dev libffi-dev python-dev -y
sudo apt-get install python-openssl python3-openssl -y
./ubuntu-unattended-setup
python3 -m pip install flask flask_cors flask_socketio pywebcopy
apt-get install python-netifaces
sudo python3 -m pip install --upgrade pyopenssl


#hostapd-wpe
cd $TOOLS
# https://github.com/aircrack-ng/aircrack-ng/tree/master/patches/wpe/hostapd-wpe
wget https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/patches/wpe/hostapd-wpe/hostapd-2.10-wpe.patch
wget https://w1.fi/releases/hostapd-2.10.tar.gz
tar -zxf hostapd-2.10.tar.gz
rm hostapd-2.10.tar.gz
cd hostapd-2.10
patch -p1 < ../hostapd-2.10-wpe.patch
rm ../hostapd-2.10-wpe.patch
cd hostapd

make
make install
make wpe

cd /etc/hostapd-wpe/certs
./bootstrap
make install

#aircrack
apt-get install aircrack-ng -y

apt-get install hashcat -y


# Creap
cd $TOOLS
git clone https://github.com/Snizz/crEAP
#Arp-scan
apt-get install arp-scan -y


#airgeddon
sudo apt-get install tshark john lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd-y
sudo apt-get install asleap bettercap ettercap-text-only hcxtools hcxdumptool bully mdk4 beef-xss -y
sudo systemctl disable lighttpd
sudo systemctl stop lighttpd
cd $TOOLS
git clone --depth 1 https://github.com/v1s1t0r1sh3r3/airgeddon.git
cd airgeddon
#sudo bash airgeddon.sh
sudo apt-get install golang git build-essential libpcap-dev libusb-1.0-0-dev libnetfilter-queue-dev -y
go get -u github.com/bettercap/bettercap


#hostapd-mana
apt-get --yes install build-essential git libnl-genl-3-dev libssl-dev build-essential pkg-config git libnl-genl-3-dev libssl-dev 
apt-get install mana-toolkit -y

cd $TOOLS
git clone https://github.com/sensepost/hostapd-mana
cd hostapd-mana
make -C hostapd -j 4

sudo ln -s /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

#eapeak
cd $TOOLS
sudo apt-get install python-dev libssl-dev swig python3-dev gcc python-m2crypto -y
sudo pip3 install pipenv

#pip2 install m2crypto
git clone https://github.com/securestate/eapeak
cd eapeak
pipenv --two install
#pipenv shell

# Reaver
sudo apt-get install libpcap-dev -y
cd $TOOLS
git clone https://github.com/t6x/reaver-wps-fork-t6x
cd reaver-wps-fork-t6x*
cd src
./configure
make
sudo make install

# wpa_sycophant
cd $TOOLS
git clone https://github.com/sensepost/wpa_sycophant
cd wpa_sycophant/
make -C wpa_supplicant -j 4


# berate_ap
cd $TOOLS
git clone https://github.com/sensepost/berate_ap

#MD4
apt-get install pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev 
cd $TOOLS
git clone https://github.com/aircrack-ng/mdk4
cd mdk4
make
sudo make install

#Air-hammer
cd $TOOLS
git clone https://github.com/Wh1t3Rh1n0/air-hammer
cd air-hammer
curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py
sudo python2 get-pip.py
pip2 install wpa_supplicant
pip2 install service_identity
 
#create_ap
#disable_hotspot.sh
#evilTrust
#pcap2csv
#pinecone
#start_hotspot.sh

# wifipumpkin3
cd $TOOLS
sudo apt-get -y install python3-dev libssl-dev libffi-dev build-essential python3 -y
sudo apt-get  install -y python3-pyqt5 python3-bs4 python3-dnslib python3-dnspython python3-flask-restful python3-isc-dhcp-leases python3-netaddr python3-scapy python3-tabulate python3-termcolor python3-twisted python3-urwid
git clone https://github.com/P0cL4bs/wifipumpkin3.git
cd wifipumpkin3
sed -i 's/python3.7/python3/g' makefile
sudo make install

# LN home user 
chown -R user $TOOLS
ln -s $TOOLS /home/user/tools

# NEW
sudo DEBIAN_FRONTEND=noninteractive apt-get install macchanger -y
sudo apt-get install curl -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install wireshark-qt -y


# wacker WPA3 brute force online
cd $TOOLS
git clone https://github.com/blunderbuss-wctf/wacker
cd wacker
sudo apt-get install -y pkg-config libnl-3-dev gcc libssl-dev libnl-genl-3-dev net-tools
cp defconfig wpa_supplicant-2.10/wpa_supplicant/.config
git apply wpa_supplicant.patch
cd wpa_supplicant-2.10/wpa_supplicant
make -j4
ls -al wpa_supplicant


#hcxtools
cd $TOOLS
#git clone https://github.com/ZerBea/hcxtools.git
git clone https://salsa.debian.org/pkg-security-team/hcxtools #to ubuntu 20
cd hcxtools
make 
sudo make install
cd ..


#Enable ssh (if dont use vagrant)
#apt-get install -y ssh
#echo Port 2222 >> /etc/ssh/sshd_config && systemctl enable ssh 

