FROM debian
#FROM kalilinux/kali-rolling

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger sudo iw libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq make g++ libnl-3-dev libnl-genl-3-dev apache2 openssl php libapache2-mod-php wpasupplicant iproute2 net-tools iptables kmod iputils-ping gettext-base wget freeradius nano


#opennds
RUN DEBIAN_FRONTEND=noninteractive apt-get install -y php-cli  systemd

RUN cd ; wget https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.71.tar.gz \
	; tar  -xf libmicrohttpd-0.9.71.tar.gz ; cd libmicrohttpd-0.9.71 \
	; ./configure --disable-https ; make ; sudo rm /usr/local/lib/libmicrohttpd* \
	; sudo make install ; sudo rm /etc/ld.so.cache ; sudo ldconfig -v ; cd ..

RUN cd ; wget wget https://codeload.github.com/opennds/opennds/tar.gz/v9.8.0 \
       ; tar -xf v9.8.0 && cd openNDS-9.8.0 ; sudo touch /dev/log \
       ; make && make install && rm -rf ~/v9.8.0 ~/openNDS-9.8.0 ~/libmicrohttpd-0.9.71 ~/libmicrohttpd-0.9.71.tar.gz 

#Copy config files
COPY config/wlan_config_clients /root/wlan_config_clients
COPY config/open/ /root/open/
COPY config/psk/ /root/psk/
COPY config/mgt/ /root/mgt/
COPY config/wpa3/ /root/wpa3/
COPY config/wep/ /root/wep/
COPY config/owe/ /root/owe/
COPY mac80211_hwsim/ /root/mac80211_hwsim_WiFiChallenge
COPY config/decode_passwords.sh /root/decode_passwords.sh
COPY config/patch_deauth_on_drop_dmesg.sh /root/patch_deauth_on_drop_dmesg.sh

#Copy freeradius files
COPY config/freeradius/clients.conf /etc/freeradius/3.0/clients.conf
COPY config/freeradius/default /etc/freeradius/3.0/sites-enabled/default
RUN rm -f /etc/freeradius/3.0/sites-enabled/inner-tunnel
COPY config/freeradius/eap /etc/freeradius/3.0/mods-enabled/eap
COPY config/freeradius/users.tmp /etc/freeradius/3.0/mods-config/files/users.tmp
COPY config/freeradius/files /etc/freeradius/3.0/mods-available/files

#Expose freeradius port
EXPOSE 1812/udp

#Copy connectINET.sh
COPY config/connectINET.sh /root/

#Copy cron
COPY config/cronAPs.sh /root/

#Update certs
#RUN cd /root/certs/ ; make install

COPY config/dnsmasq.conf.tmp /etc/dnsmasq.conf.tmp

#Copy HTML files
COPY config/html /var/www/html/
RUN mkdir /var/www/html/.internalCA/

RUN chown -R www-data:www-data /var/www/html/ 
RUN rm /var/www/html/index.html

# Make sure Apache uses index.php as the default file
RUN echo "<IfModule mod_dir.c>\n DirectoryIndex index.php index.html\n</IfModule>" > /etc/apache2/mods-enabled/dir.conf

# Enable the SSL and rewrite modules
RUN a2enmod ssl && a2enmod rewrite

# Create a custom SSL VirtualHost configuration for Apache
RUN echo "<IfModule mod_ssl.c>\n\
<VirtualHost *:443>\n\
    ServerAdmin webmaster@wifichallenge.com\n\
    DocumentRoot /var/www/html\n\
    SSLEngine on\n\
    SSLCertificateFile /root/certs/server.crt\n\
    SSLCertificateKeyFile /root/certs/server.key\n\
    <Directory /var/www/html>\n\
        Options Indexes FollowSymLinks\n\
        AllowOverride All\n\
        Require all granted\n\
    </Directory>\n\
    ErrorLog \${APACHE_LOG_DIR}/error.log\n\
    CustomLog \${APACHE_LOG_DIR}/access.log combined\n\
</VirtualHost>\n\
</IfModule>" > /etc/apache2/sites-available/default-ssl.conf

# Enable the SSL site
RUN a2ensite default-ssl.conf
RUN a2enmod ssl

#WPS 
RUN touch /var/run/hostapd_wps_pin_requests


#Change name of hostapd to avoid airmon-ng check kill, etc
RUN mv /usr/sbin/hostapd /usr/sbin/host_aps_apd


COPY config/ns-inet.sh /root/
COPY config/startAPs.sh /root/


# autoremove any dependencies that are no longer needed
RUN sudo apt-get --yes autoremove ; sudo apt-get autoclean ; sudo apt-get clean

COPY config/opennds.conf.tmp /etc/opennds/opennds.conf.tmp
COPY config/theme_user-email-login-basic.sh /usr/lib/opennds/
RUN chmod +x /usr/lib/opennds/theme_user-email-login-basic.sh

# Expose both HTTP and HTTPS ports
EXPOSE 80 443

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
