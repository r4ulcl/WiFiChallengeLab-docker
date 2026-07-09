FROM debian
#FROM kalilinux/kali-rolling
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y macchanger iw sudo libcurl4-openssl-dev curl libz-dev module-assistant libssl-dev libnl-genl-3-dev libnl-3-dev pkg-config libsqlite3-dev git hostapd dnsmasq curl kmod make g++ libnl-3-dev libnl-genl-3-dev wpasupplicant apache2 php iproute2 net-tools iptables cpulimit gettext-base nano

RUN apt-get install -y inetutils-ping isc-dhcp-client fping

RUN apt-get install -y smbmap

# autoremove any dependencies that are no longer needed
RUN sudo apt-get --yes autoremove ; sudo apt-get autoclean ; sudo apt-get clean

#RUN date

#Copy config files
COPY config/mgtClient/ /root/mgtClient/
COPY config/openClient/ /root/openClient/
COPY config/pskClient/ /root/pskClient/
COPY config/wpa3Client/ /root/wpa3Client/
COPY config/wepClient /root/wepClient/
COPY config/oweClient /root/oweClient/
COPY config/decode_passwords.sh /root/decode_passwords.sh

#Copy connectINET.sh
COPY config/connectINET.sh /root/

#Update certs
#RUN cd /root/certs/ ; make install

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
# Build wpa_supplicant 2.10 from source WITH TLS 1.3 (CONFIG_TLSV13=y) and use it
# as the client binary. Debian's stock wpa_supplicant is NOT built with
# CONFIG_TLSV13, so the EAP-TLS-over-TLS-1.3 client (wpa_TLS.conf) fails every
# handshake with "SSL routines::unsupported protocol" while the AP (hostapd,
# already built with TLSV13) offers 1.3 - only the TLS 1.2 client works otherwise.
# Mirror the AP build: start from upstream defconfig and re-enable the features the
# lab's clients use (nl80211 + WEP/SAE/OWE + EAP) alongside TLSV12/TLSV13.
# CONFIG_EAP_SIM/AKA/AKA_PRIME let the leaking wifi-passpoint client authenticate
# with a software (U)SIM: wpa_supplicant runs Milenage from the Ki:OPc:SQN in its
# config, so no PC/SC card reader is needed. These are OFF in upstream defconfig.
RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends build-essential wget libnl-route-3-dev \
 && cd /tmp \
 && wget -q https://w1.fi/releases/wpa_supplicant-2.10.tar.gz \
 && tar xf wpa_supplicant-2.10.tar.gz \
 && cd wpa_supplicant-2.10/wpa_supplicant \
 && cp defconfig .config \
 && sed -i '/^CONFIG_CTRL_IFACE_DBUS/d' .config \
 && printf '%s\n' \
      'CONFIG_DRIVER_NL80211=y' \
      'CONFIG_LIBNL32=y' \
      'CONFIG_WEP=y' \
      'CONFIG_SAE=y' \
      'CONFIG_OWE=y' \
      'CONFIG_EAP_SIM=y' \
      'CONFIG_EAP_AKA=y' \
      'CONFIG_EAP_AKA_PRIME=y' \
      'CONFIG_TLSV12=y' \
      'CONFIG_TLSV13=y' \
      'CFLAGS += -Wno-error' >> .config \
 && make -j"$(nproc)" wpa_supplicant \
 && install -m 0755 wpa_supplicant /sbin/wpa_wifichallenge_supplicant \
 && rm -rf /tmp/wpa_supplicant-2.10*
RUN cp /sbin/dhclient /sbin/dhclien-wifichallenge


#Fix buf soft lockup, delete in docker?
#RUN echo "kernel.watchdog_thresh=20" > /etc/sysctl.d/99-watchdog_thresh.conf && sysctl -p  /etc/sysctl.d/99-watchdog_thresh.conf

COPY config/ns-inet.sh /root/
COPY config/startClients.sh /root/
COPY config/cronClients.sh /root/

# exec ns-inet.sh and waits aits
CMD ["/bin/bash", "/root/ns-inet.sh"]
