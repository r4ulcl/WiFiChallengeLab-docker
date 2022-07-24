FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger sudo  iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq make g++ libnl-3-dev libnl-genl-3-dev apache2 php wpasupplicant iproute2 net-tools iptables kmod
#nzyme install
RUN apt-get update && apt-get install -y libpcap0.8 openjdk-11-jre-headless wireless-tools systemd libpam-systemd postgresql gettext-base curl python3

#RUN date

#Copy config files
COPY config/open/ /root/open/
COPY config/wep/ /root/wep/
COPY config/psk/ /root/psk/
COPY config/mgt/ /root/mgt/
COPY config/certs/ /root/mgt/certs/

#Copy cron
COPY config/cronAPs.sh /root/

#Update certs
#RUN cd /root/mgt/certs/ ; make install

COPY config/dnsmasq.conf /etc/dnsmasq.conf
COPY config/interfaces /etc/network/interfaces

#Copy HTML files
COPY config/html /var/www/html/
RUN mkdir /var/www/html/secretCA/
RUN cp /root/mgt/certs/ca.crt /var/www/html/secretCA/ca.crt.txt ;split -l 15  /root/mgt/certs/ca.key /var/www/html/secretCA/ca.key.txt. -a1 ; cp /root/mgt/certs/ca.serial /var/www/html/secretCA/ca.serial.txt ; cp /root/mgt/certs/server.crt /var/www/html/secretCA/server.crt.txt ; split -l 15 /root/mgt/certs/server.key /var/www/html/secretCA/server.key.txt. -a1 ; chown -R www-data:www-data /var/www/html/ ; rm /var/www/html/index.html

#WPS 
RUN touch /var/run/hostapd_wps_pin_requests

#Apache
RUN update-rc.d apache2 defaults


#Change name of wpa_supplicant to avoid airmon-ng check kill, etc
RUN mv /usr/sbin/hostapd /usr/sbin/hostapd_aps


#RUN apt-get update && apt-get install -y linux-image-amd64 linux-headers-amd64

# Fix buf soft lockup, delete in docker?
#RUN echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf && sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf

COPY config/ns-inet.sh /root/
COPY config/startAPs.sh /root/

#nzyme
RUN curl -s https://assets.nzyme.org/releases/nzyme-1.2.2.deb -o nzyme.deb && dpkg -i nzyme.deb && rm nzyme.deb
COPY config/nzyme.conf  /etc/nzyme/nzyme.conf
RUN service postgresql start && sudo -u postgres psql -c "create database nzyme;" && sudo -u postgres psql -c "create user nzyme with encrypted password 'NEW_PASSWORD'; grant all privileges on database nzyme to nzyme;"
#/bin/sh /usr/share/nzyme/bin/nzyme


# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
