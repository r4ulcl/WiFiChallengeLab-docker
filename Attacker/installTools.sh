#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

sudo apt-get install curl git -y

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

sudo apt-get update
sudo apt-get upgrade -y

sudo apt-get install nmap -y

# Python
sudo apt-get install -y python3 


# EAP_buster
cd $TOOLS
git clone https://github.com/blackarrowsec/EAP_buster

# OpenSSL 3 for ubuntu
sudo apt-get install build-essential checkinstall zlib1g-dev -y
cd /usr/local/src/
VERSION='openssl-3.2.1'
wget https://www.openssl.org/source/$VERSION.tar.gz
tar -xvf $VERSION.tar.gz > /dev/null
rm $VERSION.tar.gz
cd $VERSION
./config --prefix=/usr/local/openssl --openssldir=/usr/local/openssl shared zlib

# Update the library path in .bashrc
#echo 'export PATH=/usr/local/openssl/bin:$PATH' >> ~/.bashrc
#echo 'export LD_LIBRARY_PATH=/usr/local/openssl/lib:$LD_LIBRARY_PATH' >> ~/.bashrc
#echo 'export PKG_CONFIG_PATH=/usr/local/openssl/lib/pkgconfig:$PKG_CONFIG_PATH' >> ~/.bashrc

# Source .bashrc to apply changes
source ~/.bashrc

make -j $(nproc)
#make test
make install

#wifi_db
cd $TOOLS
sudo apt-get install python3-pip sqlitebrowser -y
sudo DEBIAN_FRONTEND=noninteractive apt-get install tshark -y
sudo apt install pkg-config libcurl4-openssl-dev libssl-dev zlib1g-dev make gcc -y

#git clone https://salsa.debian.org/pkg-security-team/hcxtools ##6.2.7
git clone https://github.com/ZerBea/hcxtools.git
cd hcxtools
git checkout 6.2.7

make -j $(nproc)
sudo make install
cd ..

git clone https://github.com/r4ulcl/wifi_db
cd wifi_db
pip3 install -r requirements.txt 

# pcapFilter.sh
cd $TOOLS
wget https://gist.githubusercontent.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2/raw/78e097e1d4a9eb5f43ab0b2763195c04f02c4998/pcapFilter.sh
chmod +x pcapFilter.sh

# UnicastDeauth
git clone 'https://github.com/mamatb/UnicastDeauth.git'
pip install -r './UnicastDeauth/requirements.txt'

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
sudo apt-get install python-netifaces -y
sudo python3 -m pip install --upgrade pyopenssl

wget https://raw.githubusercontent.com/lgandx/Responder/master/Responder.conf -O /root/tools/eaphammer/settings/core/Responder.ini

# Hostapd-wpe
cd $TOOLS
# https://github.com/aircrack-ng/aircrack-ng/tree/master/patches/wpe/hostapd-wpe
apt install libsqlite3-dev -y
wget https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/52925bbdd13f739af6fc32e11f589b8c3e6e1fe5/patches/wpe/hostapd-wpe/hostapd-2.11-wpe.patch
wget https://w1.fi/releases/hostapd-2.11.tar.gz
tar -zxf hostapd-2.11.tar.gz
rm hostapd-2.11.tar.gz
cd hostapd-2.11
patch -p1 < ../hostapd-2.11-wpe.patch
rm ../hostapd-2.11-wpe.patch
cd hostapd

sudo apt install libsqlite3-dev -y

make
make install
make wpe

cd /etc/hostapd-wpe/certs
./bootstrap
make install

#aircrack
apt-get install aircrack-ng -y

# hashcat
cd $TOOLS
# Install old version to dependencies
sudo apt-get install hashcat p7zip -y
#sudo apt install build-essential mesa-opencl-icd ocl-icd-libopencl1 ocl-icd-opencl-dev opencl-headers -y

wget https://hashcat.net/files/hashcat-6.0.0.7z
sudo p7zip -d hashcat-6.0.0.7z
rm hashcat-6.0.0.7z

# Delete old version of hashcat to avoid confusion. 
rm /usr/bin/hashcat

#cd hashcat-6.0.0/
#sudo cp hashcat.bin /usr/bin/
#sudo ln -s /usr/bin/hashcat.bin /usr/bin/hashcat
#sudo cp -Rv OpenCL/ /usr/bin/
#sudo cp -Rv modules/ /usr/bin/
#udo cp hashcat.hcstat2 /usr/bin/
#sudo cp hashcat.hctune /usr/bin/

echo "alias hashcat='~/tools/hashcat-6.0.0/hashcat.bin'" >> /root/.bashrc
echo "alias hashcat='sudo ~/tools/hashcat-6.0.0/hashcat.bin'" >> /home/user/.bashrc

# Creap
cd $TOOLS
git clone https://github.com/Snizz/crEAP
#Arp-scan
apt-get install arp-scan -y


#airgeddon
sudo apt-get install tshark john lighttpd pixiewps isc-dhcp-server reaver crunch xterm hostapd -y
sudo apt-get install ettercap-text-only hcxdumptool mdk4 -y
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
sudo apt-get install python-dev libssl-dev swig python3-dev gcc -y
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
apt-get install pkg-config libnl-3-dev libnl-genl-3-dev libpcap-dev -y
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
pip2 install -U setuptools 
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
make -j $(nproc)
ls -al wpa_supplicant


#hcxtools
cd $TOOLS
#git clone https://github.com/ZerBea/hcxtools.git
git clone https://salsa.debian.org/pkg-security-team/hcxtools #to ubuntu 20
cd hcxtools
make 
sudo make install
cd ..


# wifiphisher
cd $TOOLS
git clone https://github.com/wifiphisher/extra-phishing-pages

git clone https://github.com/wifiphisher/wifiphisher.git # Download the latest revision
cd wifiphisher # Switch to tool's directory
sudo python3 setup.py install # Install any dependencies

# wifite2
cd $TOOLS
git clone https://github.com/derv82/wifite2.git
cd wifite2
sudo python3 setup.py install

# Fluxion
#cd $TOOLS
#git clone https://www.github.com/FluxionNetwork/fluxion.git
#cd fluxion 
#./fluxion.sh

# Kismet
##sudo apt-get install -y build-essential git libwebsockets-dev pkg-config zlib1g-dev libnl-3-dev libnl-genl-3-dev libcap-dev libpcap-dev libnm-dev libdw-dev libsqlite3-dev libprotobuf-dev libprotobuf-c-dev protobuf-compiler protobuf-c-compiler libsensors4-dev libusb-1.0-0-dev python3 python3-setuptools python3-protobuf python3-requests python3-numpy python3-serial python3-usb python3-dev python3-websockets librtlsdr0 libubertooth-dev libbtbb-dev
#sudo DEBIAN_FRONTEND=noninteractive apt-get install -y kismet

# assless-chaps
cd $TOOLS
git clone https://github.com/sensepost/assless-chaps
python3 -m pip install pycryptodome
bzip2 -d  assless-chaps/10-million-password-list-top-1000000.db.bz2

#Enable ssh (if dont use vagrant)
#apt-get install -y ssh
#echo Port 2222 >> /etc/ssh/sshd_config && systemctl enable ssh 

sudo systemctl disable lighttpd