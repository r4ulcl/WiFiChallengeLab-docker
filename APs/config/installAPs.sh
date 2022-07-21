#!/bin/bash
apt update
apt install macchanger -y
apt install sudo  iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq -y
apt install make g++ libnl-3-dev libnl-genl-3-dev -y
apt install apache2 php  -y #Web server
apt-get install wpasupplicant -y

# Git vwifi
git clone https://github.com/Raizo62/vwifi
cd vwifi
make
make tools # To change the file mode bits of tools
sudo make install


cd /root

# Hostapd-wpe to debug
# https://github.com/aircrack-ng/aircrack-ng/tree/master/patches/wpe/hostapd-wpe
wget https://raw.githubusercontent.com/aircrack-ng/aircrack-ng/master/patches/wpe/hostapd-wpe/hostapd-2.10-wpe.patch
wget https://w1.fi/releases/hostapd-2.10.tar.gz
tar -zxf hostapd-2.10.tar.gz
cd hostapd-2.10
patch -p1 < ../hostapd-2.10-wpe.patch
cd hostapd

make
#make install 
make wpe


cd /etc/hostapd-wpe/certs
./bootstrap
make install

# Hostapd
apt remove hostapd -y
apt install hostapd -y

# Hostapd 2.6 krackattacks
cd /root
mkdir krack
cd krack
wget https://w1.fi/releases/hostapd-2.6.tar.gz
tar -zxf hostapd-2.6.tar.gz
cd hostapd-2.6/hostapd
cp defconfig .config
sed -i '/CONFIG_LIBNL32=y/s/^#//g' .config # remove comment
make

# Hostapd config PSK!!
cd /root
wget -nH -r --no-parent http://192.168.190.15/APs/psk/

# Open
cd /root
wget -nH -r --no-parent http://192.168.190.15/APs/open/

# WEP
cd /root
wget -nH -r --no-parent http://192.168.190.15/APs/wep/

# MGT
cd /root
wget -nH -r --no-parent http://192.168.190.15/APs/mgt/

mkdir /root/mgt/
cd /root/mgt/
wget -nH -r --no-parent http://192.168.190.15/certs
cd certs
make install

cd
cp APs/* . -r

# DNSMASQ
echo '
server=8.8.8.8
server=8.8.4.4

dhcp-option=3 #Disable default router gateway
dhcp-option=6 # Disables DNS

dhcp-host=wlan0,F0:9F:C2:71:22:00,192.168.0.1
dhcp-range=192.168.0.2,192.168.0.100,24h

dhcp-host=wlan1,F0:9F:C2:71:22:11,192.168.1.1
dhcp-range=192.168.1.2,192.168.1.100,24h

dhcp-host=wlan2,F0:9F:C2:71:22:22,192.168.2.1
dhcp-range=192.168.2.2,192.168.2.100,24h

dhcp-host=wlan3,F0:9F:C2:71:22:33,192.168.3.1
dhcp-range=192.168.3.2,192.168.3.100,24h

dhcp-host=wlan4,F0:9F:C2:71:22:44,192.168.4.1
dhcp-range=192.168.4.2,192.168.4.100,24h

dhcp-host=wlan5,F0:9F:C2:71:22:55,192.168.5.1
dhcp-range=192.168.5.2,192.168.5.100,24h

dhcp-host=wlan6,F0:9F:C2:71:22:66,192.168.6.1
dhcp-range=192.168.6.2,192.168.6.100,24h

dhcp-host=wlan7,F0:9F:C2:71:22:77,192.168.7.1
dhcp-range=192.168.7.2,192.168.7.100,24h

dhcp-host=wlan8,F0:9F:C2:71:22:88,192.168.8.1
dhcp-range=192.168.8.2,192.168.8.100,24h


# Other

dhcp-host=wlan9,8d:4c:02:22:c9:33,192.168.9.1
dhcp-range=192.168.9.2,192.168.9.100,24h

dhcp-host=wlan10,4f:c2:15:67:f1:87,192.168.10.1
dhcp-range=192.168.10.2,192.168.10.100,24h

dhcp-host=wlan11,f8:b5:cd:67:50:d5,192.168.11.1
dhcp-range=192.168.11.2,192.168.11.100,24h

dhcp-host=wlan12,98:ab:c9:01:8d:e1,192.168.12.1
dhcp-range=192.168.12.2,192.168.12.100,24h

dhcp-host=wlan13,76:c4:de:29:5f:b9,192.168.13.1
dhcp-range=192.168.13.2,192.168.13.100,24h

' >> /etc/dnsmasq.conf

# Config autoStart
echo '#!/bin/sh -e

nohup /root/startAPs.sh &

exit 0
' >>  /etc/rc.local
chmod 755 /etc/rc.local

echo '
auto enp0s3
iface enp0s3 inet static
  address 192.168.190.14 
  netmask 255.255.255.0
  gateway 192.168.190.2
  dns-nameservers 8.8.8.8
' >> /etc/network/interfaces

sed '/inet dhcp/d' /etc/network/interfaces -i
sed '/allow-hotplug enp0s3/d' /etc/network/interfaces -i

cd /root
wget 192.168.190.15/APs/startAPs.sh
chmod +x /root/startAPs.sh

wget 192.168.190.15/APs/cronAPs.sh
chmod +x /root/cronAPs.sh

cd /root
wget 192.168.190.15/checkVWIFI.sh
chmod +x /root/checkVWIFI.sh

export PATH=$PATH:/sbin

cd 
rm -r /var/www/html
wget -nH -r --no-parent http://192.168.190.15/APs/html/
cp -r APs/html/ /var/www/

# CA To web
mkdir -p  /var/www/html/secretCA/
cp /root/mgt/certs/ca.crt /var/www/html/secretCA/ca.crt.txt
split -l 15  /root/mgt/certs/ca.key /var/www/html/secretCA/ca.key.txt. -a1
cp /root/mgt/certs/ca.serial /var/www/html/secretCA/ca.serial.txt
cp /root/mgt/certs/server.crt /var/www/html/secretCA/server.crt.txt
split -l 15 /root/mgt/certs/server.key /var/www/html/secretCA/server.key.txt. -a1
cp /etc/hostapd-wpe/dh /var/www/html/secretCA/dh.txt

chown -R www-data:www-data /var/www/html/
rm /var/www/html/index.html

#WPS
touch /var/run/hostapd_wps_pin_requests

service apache2 start

#CRON
#line="*/10 * * * * sh /root/cronAPs.sh"
#(crontab -u root -l; echo "$line" ) | crontab -u root -

#Bug: soft lockup
#https://www.suse.com/support/kb/doc/?id=000018705
#echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf
echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf
sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf