FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger iw sudo libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq curl kmod make g++ libnl-3-dev libnl-genl-3-dev wpasupplicant apache2 php iproute2 net-tools iptables

RUN apt-get install -y inetutils-ping isc-dhcp-client

RUN apt-get install -y smbmap

# autoremove any dependencies that are no longer needed
RUN sudo apt-get --yes autoremove ; sudo apt-get autoclean ; sudo apt-get clean

#RUN date

#COPY var file
COPY config/wlan_config_clients /root/

#Copy config files
COPY config/certs/ /root/certs/
COPY config/mgtClient/ /root/mgtClient/
COPY config/openClient/ /root/openClient/
COPY config/pskClient/ /root/pskClient/
COPY config/wpa3Client/ /root/wpa3Client/
COPY config/wepClient /root/wepClient

#Copy connectINET.sh
COPY config/connectINET.sh /root/

#Update certs
#RUN cd /root/mgt/certs/ ; make install

#COPY config/dnsmasq.conf /etc/dnsmasq.conf
# Not used COPY config/interfaces /etc/network/interfaces

#Copy HTML files
COPY config/html /var/www/html/
RUN rm /var/www/html/index.html

#Apache
#COPY config/ports.conf /etc/apache2/ports.conf
RUN update-rc.d apache2 defaults


#RUN apt-get update && apt-get install -y linux-image-amd64 linux-headers-amd64

#Change name of wpa_supplicant to avoid airmon-ng check kill and dhclient
RUN cp /sbin/wpa_supplicant /sbin/wpa_wifichallenge_supplicant
RUN cp /sbin/dhclient /sbin/dhclien-wifichallenge


#Fix buf soft lockup, delete in docker?
#RUN echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf && sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf

COPY config/ns-inet.sh /root/
COPY config/startClients.sh /root/
COPY config/cronClients.sh /root/

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
