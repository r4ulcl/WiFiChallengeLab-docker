#!/bin/bash
apt update
apt install macchanger -y
apt install iw sudo libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq curl -y
apt install make g++ libnl-3-dev libnl-genl-3-dev -y
apt-get install wpasupplicant -y
apt install apache2 php  -y #Web server

# Git vwifi
git clone https://github.com/Raizo62/vwifi
cd vwifi
make
make tools # To change the file mode bits of tools
sudo make install
cd ..

cd /root
wget -nH -r --no-parent http://192.168.190.15/certs

# Download wpa_supplicant files wget
cd /root
wget -nH -r --no-parent http://192.168.190.15/Clients/pskClient/

cd /root
wget -nH -r --no-parent http://192.168.190.15/Clients/mgtClient/

cd /root
wget -nH -r --no-parent http://192.168.190.15/Clients/openClient/

cp Clients/* . -r

# Config autoStart
echo '#!/bin/sh -e

nohup /root/startClients.sh &

exit 0
' >>  /etc/rc.local
chmod 755 /etc/rc.local


# SET IP
echo '
auto enp0s3 
iface enp0s3 inet static
  address 192.168.190.16 
  netmask 255.255.255.0
  gateway 192.168.190.2
  dns-nameservers 8.8.8.8
' >> /etc/network/interfaces

sed '/inet dhcp/d' /etc/network/interfaces -i
sed '/allow-hotplug enp0s3/d' /etc/network/interfaces -i

cd /root
wget 192.168.190.15/Clients/startClients.sh
chmod +x /root/startClients.sh

wget 192.168.190.15/Clients/cronClients.sh
chmod +x /root/cronClients.sh

cd /root
wget 192.168.190.15/checkVWIFI.sh
chmod +x /root/checkVWIFI.sh

cd 
rm -r /var/www/html
wget -nH -r --no-parent http://192.168.190.15/Clients/html/
cp -r Clients/html/ /var/www/
chown -R www-data:www-data /var/www/html/
rm /var/www/html/index.html

export PATH=$PATH:/sbin

# CRON
line="*/2 * * * * sh /root/cronClients.sh"
(crontab -u root -l; echo "$line" ) | crontab -u root -

#Bug: soft lockup
#https://www.suse.com/support/kb/doc/?id=000018705
#echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf
echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf
sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf