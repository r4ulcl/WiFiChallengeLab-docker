FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger sudo  iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq make g++ libnl-3-dev libnl-genl-3-dev apache2 php wpasupplicant iproute2 net-tools iptables kmod iputils-ping gettext-base

RUN date

#Copy config files
COPY config/open/ /root/open/
COPY config/wep/ /root/wep/
COPY config/psk/ /root/psk/
COPY config/mgt/ /root/mgt/
COPY config/wpa3/ /root/wpa3/
COPY config/certs/ /root/mgt/certs/

#COPY var file
COPY config/wlan_config /root/

#Copy cron
COPY config/cronAPs.sh /root/

#Update certs
#RUN cd /root/mgt/certs/ ; make install

COPY config/dnsmasq.conf /etc/dnsmasq.conf.tmp
COPY config/interfaces /etc/network/interfaces.tmp

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


# Hostapd 2.6 krackattacks
RUN apt-get install -y wget
RUN cd /root && mkdir krack && cd krack && wget https://w1.fi/releases/hostapd-2.6.tar.gz && tar -zxf hostapd-2.6.tar.gz \
	&& cd hostapd-2.6/hostapd && cp defconfig .config && sed -i '/CONFIG_LIBNL32=y/s/^#//g' .config # remove comment \
	&& make

#RUN apt-get update && apt-get install -y linux-image-amd64 linux-headers-amd64

# Fix buf soft lockup, delete in docker?
#RUN echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf && sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf

COPY config/ns-inet.sh /root/
COPY config/startAPs.sh /root/

#opennds
RUN cd ; wget https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.75.tar.gz \
	; tar  -xf libmicrohttpd-0.9.75.tar.gz ; cd libmicrohttpd-0.9.75 \
	; ./configure --disable-https ; make ; sudo rm /usr/local/lib/libmicrohttpd* \
	; sudo make install ; sudo rm /etc/ld.so.cache ; sudo ldconfig -v ; cd ..

RUN cd && wget https://codeload.github.com/opennds/opennds/tar.gz/v9.7.0 && tar -xf v9.7.0 && cd openNDS-9.7.0 \
	 && make && make install && rm -rf ~/openNDS-9.7.0 ~/libmicrohttpd-0.9.75

COPY config/opennds.conf /etc/opennds/opennds.conf
COPY config/theme_user-email-login-basic.sh /usr/lib/opennds/
RUN chmod +x /usr/lib/opennds/theme_user-email-login-basic.sh

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
