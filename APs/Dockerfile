FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger sudo  iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq make g++ libnl-3-dev libnl-genl-3-dev apache2 php wpasupplicant iproute2 net-tools iptables kmod iputils-ping gettext-base wget

#RUN date

#Copy config files
COPY config/open/ /root/open/
COPY config/psk/ /root/psk/
COPY config/mgt/ /root/mgt/
COPY config/wpa3/ /root/wpa3/
COPY config/certs/ /root/mgt/certs/

#COPY var file
COPY config/wlan_config_aps /root/

#Copy connectINET.sh
COPY config/connectINET.sh /root/

#Copy cron
COPY config/cronAPs.sh /root/

#Update certs
#RUN cd /root/mgt/certs/ ; make install

COPY config/dnsmasq.conf /etc/dnsmasq.conf.tmp
COPY config/interfaces /etc/network/interfaces.tmp

#Copy HTML files
COPY config/html /var/www/html/
RUN mkdir /var/www/html/secretCA/
RUN cp /root/mgt/certs/ca.crt /var/www/html/secretCA/ca.crt.txt \
	; cp /root/mgt/certs/ca.key /var/www/html/secretCA/ca.key.txt \
	; cp /root/mgt/certs/ca.serial /var/www/html/secretCA/ca.serial.txt \
	; cp /root/mgt/certs/server.crt /var/www/html/secretCA/server.crt.txt \
	; cp /root/mgt/certs/server.key /var/www/html/secretCA/server.key.txt  \
	; chown -R www-data:www-data /var/www/html/ ; rm /var/www/html/index.html

#WPS 
RUN touch /var/run/hostapd_wps_pin_requests

#Apache
RUN update-rc.d apache2 defaults


#Change name of wpa_supplicant to avoid airmon-ng check kill, etc
RUN mv /usr/sbin/hostapd /usr/sbin/hostapd_aps


COPY config/ns-inet.sh /root/
COPY config/startAPs.sh /root/

#opennds
RUN cd ; wget https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.75.tar.gz \
	; tar  -xf libmicrohttpd-0.9.75.tar.gz ; cd libmicrohttpd-0.9.75 \
	; ./configure --disable-https ; make ; sudo rm /usr/local/lib/libmicrohttpd* \
	; sudo make install ; sudo rm /etc/ld.so.cache ; sudo ldconfig -v ; cd ..

RUN cd ; wget wget https://codeload.github.com/opennds/opennds/tar.gz/v9.8.0 \
       ; tar -xf v9.8.0 && cd openNDS-9.8.0 \
       ; make && make install && rm -rf ~/openNDS-9.8.0 ~/libmicrohttpd-0.9.75 ~/libmicrohttpd-0.9.75.tar.gz ~/v9.8.0



COPY config/opennds.conf.tmp /etc/opennds/opennds.conf.tmp
COPY config/theme_user-email-login-basic.sh /usr/lib/opennds/
RUN chmod +x /usr/lib/opennds/theme_user-email-login-basic.sh

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
