FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger sudo  iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq make g++ libnl-3-dev libnl-genl-3-dev apache2 php wpasupplicant iproute2 net-tools iptables kmod

#Copy config files
COPY config/open/ /root/open/
COPY config/wep/ /root/wep/
COPY config/psk/ /root/psk/
COPY config/mgt/ /root/mgt/
COPY config/certs/ /root/mgt/certs/
#Update certs
#RUN cd /root/mgt/certs/ ; make install

COPY config/dnsmasq.conf /etc/dnsmasq.conf
COPY config/interfaces /etc/network/interfaces

#Copy HTML files
COPY config/html /var/www/html/
RUN cp /root/mgt/certs/ca.crt /var/www/html/secretCA/ca.crt.txt ;split -l 15  /root/mgt/certs/ca.key /var/www/html/secretCA/ca.key.txt. -a1 ; cp /root/mgt/certs/ca.serial /var/www/html/secretCA/ca.serial.txt ; cp /root/mgt/certs/server.crt /var/www/html/secretCA/server.crt.txt ; split -l 15 /root/mgt/certs/server.key /var/www/html/secretCA/server.key.txt. -a1 ; cp /etc/hostapd-wpe/dh /var/www/html/secretCA/dh.txt ; chown -R www-data:www-data /var/www/html/ ; rm /var/www/html/index.html

#WPS 
RUN touch /var/run/hostapd_wps_pin_requests

#Apache
RUN update-rc.d apache2 defaults


#RUN apt-get update && apt-get install -y linux-image-amd64 linux-headers-amd64

# Fix buf soft lockup, delete in docker?
#RUN echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf && sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf

COPY config/ns-inet.sh /root/
COPY config/startAPs.sh /root/

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
