FROM debian
#FROM kalilinux/kali-rolling

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y \
      macchanger sudo iw libcurl4-openssl-dev curl libz-dev module-assistant \
      libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git \
      hostapd dnsmasq make gcc g++ gcc-12 g++-12 build-essential apache2 openssl php \
      libapache2-mod-php wpasupplicant iproute2 net-tools iptables kmod \
      iputils-ping gettext-base wget freeradius nano \
      php-cli systemd \
 && rm -rf /var/lib/apt/lists/*

RUN cd ; wget https://ftp.gnu.org/gnu/libmicrohttpd/libmicrohttpd-0.9.71.tar.gz \
	; tar  -xf libmicrohttpd-0.9.71.tar.gz ; cd libmicrohttpd-0.9.71 \
	; ./configure --disable-https ; make ; sudo rm /usr/local/lib/libmicrohttpd* \
	; sudo make install ; sudo rm /etc/ld.so.cache ; sudo ldconfig -v ; cd ..

RUN cd ; wget https://codeload.github.com/opennds/opennds/tar.gz/v9.8.0 \
       ; tar -xf v9.8.0 && cd openNDS-9.8.0 ; sudo touch /dev/log \
       ; make && make install && rm -rf ~/v9.8.0 ~/openNDS-9.8.0 ~/libmicrohttpd-0.9.71 ~/libmicrohttpd-0.9.71.tar.gz 

#Copy config files
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

# Enable the SSL site (ssl module already enabled above)
RUN a2ensite default-ssl.conf

#WPS 
RUN touch /var/run/hostapd_wps_pin_requests


#Change name of hostapd to avoid airmon-ng check kill, etc
RUN mv /usr/sbin/hostapd /usr/sbin/host_aps_apd

# Build hostapd 2.10 from source WITH TLS 1.3 (CONFIG_TLSV13=y) and use it as the
# AP binary. Debian's stock hostapd 2.10 is not compiled with CONFIG_TLSV13, so
# EAP-TLS over TLS 1.3 (the secure wifi-universal client) would otherwise be
# unavailable and every EAP-TLS handshake would fall back to cleartext TLS 1.2.
# NOTE: this one binary serves ALL lab SSIDs, so we start from upstream defconfig
# and re-enable every feature the lab uses (WEP/WPS/SAE/OWE/EAP server + nl80211 +
# HT/VHT/HE) alongside TLSV13.
# CONFIG_IEEE80211R (below) is now a harmless leftover: the wifi-campus roam APs
# were switched to plain WPA2-PSK (no FT-PSK) so the client-less PMKID target is
# reliable under mac80211_hwsim, and no active hostapd config requires FT anymore.
# Build deps (make, gcc, libssl-dev, libnl-*-dev,
# pkg-config, wget) are already installed above.
# EAP-SIM/AKA/AKA' (CONFIG_EAP_SIM/AKA/AKA_PRIME) drive the SIM/USIM AP
# upstream defconfig ships them commented-out, so we turn them on
# here and additionally build hlr_auc_gw - the software HLR/AuC that answers
# hostapd's eap_sim_db socket with Milenage vectors, so no physical SIM or PC/SC
# reader is required.
# wifi-campus client-less PMKID patch: since hostapd 2.10, wpa_auth.c deliberately
# omits the PMKID KDE from EAPOL msg 1/4 for plain WPA2-PSK (anti-PMKID-attack
# hardening) -- it is only added for 802.1X/EAP, SAE and OWE. That makes the
# client-less PMKID target (APs/PMKID_TESTING.md) impossible: hostapd sends msg1
# with "WPA Key Data Length: 0" and hcxdumptool captures no PMKID. Re-add PSK to
# that condition so the PMKID KDE (derived from the PMK in the else branch) is
# emitted again, matching typical real-world/consumer AP behaviour. Applies to all
# lab WPA2-PSK APs; the grep guard fails the build if upstream renames the anchor.
RUN cd /tmp \
 && wget -q https://w1.fi/releases/hostapd-2.10.tar.gz \
 && tar xf hostapd-2.10.tar.gz \
 && cd hostapd-2.10/hostapd \
 && sed -i 's#(wpa_key_mgmt_wpa_ieee8021x(sm->wpa_key_mgmt) ||#(wpa_key_mgmt_wpa_psk(sm->wpa_key_mgmt) || /* WiFiChallenge: PMKID in M1/4 for WPA2-PSK (client-less PMKID lab target) */\n\t     wpa_key_mgmt_wpa_ieee8021x(sm->wpa_key_mgmt) ||#' ../src/ap/wpa_auth.c \
 && grep -q 'WiFiChallenge: PMKID in M1/4 for WPA2-PSK' ../src/ap/wpa_auth.c \
 && cp defconfig .config \
 && printf '%s\n' \
      'CONFIG_DRIVER_NL80211=y' \
      'CONFIG_LIBNL32=y' \
      'CONFIG_IEEE80211N=y' \
      'CONFIG_IEEE80211AC=y' \
      'CONFIG_IEEE80211AX=y' \
      'CONFIG_IEEE80211R=y' \
      'CONFIG_WEP=y' \
      'CONFIG_WPS=y' \
      'CONFIG_SAE=y' \
      'CONFIG_OWE=y' \
      'CONFIG_EAP_FAST=y' \
      'CONFIG_EAP_SIM=y' \
      'CONFIG_EAP_AKA=y' \
      'CONFIG_EAP_AKA_PRIME=y' \
      'CONFIG_TLSV12=y' \
      'CONFIG_TLSV13=y' \
      'CFLAGS += -Wno-error' >> .config \
 && make -j"$(nproc)" \
 && make -j"$(nproc)" hlr_auc_gw \
 && install -m 0755 hostapd /usr/sbin/host_aps_apd \
 && install -m 0755 hostapd_cli /usr/sbin/hostapd_cli \
 && install -m 0755 hlr_auc_gw /usr/sbin/hlr_auc_gw \
 && rm -rf /tmp/hostapd-2.10*


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
