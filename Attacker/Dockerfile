FROM kalilinux/kali-rolling as builder

RUN mkdir /root/tools

WORKDIR /root/tools

RUN apt-get update && apt-get install -y nmap python3 git make wget

RUN cd /root/tools && git clone https://github.com/blackarrowsec/EAP_buster
#RUN cd /root/tools && git clone https://github.com/ZerBea/hcxtools.git \ 
#    && cd hcxtools && make && make install

RUN cd /root/tools &&  apt-get install python3-pip -y \
    && DEBIAN_FRONTEND=noninteractive apt-get install tshark -y \
    && git clone https://github.com/RaulCalvoLaorden/wifi_db \
    && cd wifi_db && pip3 install -r requirements.txt \
    && wget https://gist.githubusercontent.com/RaulCalvoLaorden/f3470f097d1cd21dbc5a238883e79fb2/raw/pcapFilter.sh

RUN cd /root/tools && git clone https://github.com/Snizz/crEAP

RUN apt-get install -y eaphammer hostapd-wpe aircrack-ng arp-scan airgeddon \ 
    build-essential libnl-genl-3-dev libssl-dev build-essential \ 
    pkg-config git libnl-genl-3-dev libssl-dev reaver

#RUN apt-get install -y mana-toolkit eapeak wpa_sycophant berate_ap air-hammer create_ap 
RUN apt-get install -y mdk4 wifipumpkin3 libpcap-dev curl

#hostapd mana
RUN cd /root/tools && git clone https://github.com/sensepost/hostapd-mana && cd hostapd-mana \ 
	&& make -C hostapd -j 4 && ln -s /root/tools/hostapd-mana/hostapd/hostapd /usr/bin/hostapd-mana

# EAPEAK
#RUN cd /root/tools && apt-get install libssl-dev swig python3-dev gcc -y \
#	&& pip3 install pipenv && git clone https://github.com/securestate/eapeak \
#	&& cd eapeak && pipenv --two install

#Reaver
RUN cd /root/tools && git clone https://github.com/t6x/reaver-wps-fork-t6x && cd reaver-wps-fork-t6x* \
	&& cd src && ./configure && make && make install

#wpa_sycophant
RUN cd /root/tools && git clone https://github.com/sensepost/wpa_sycophant && cd wpa_sycophant/ \
	&& make -C wpa_supplicant -j 4

#berate_ap
RUN cd /root/tools && git clone https://github.com/sensepost/berate_ap

RUN apt-get install -y python2

#air-hammer
RUN cd /root/tools && git clone https://github.com/Wh1t3Rh1n0/air-hammer && cd air-hammer \
	&& curl https://bootstrap.pypa.io/pip/2.7/get-pip.py --output get-pip.py \
	&& python2 get-pip.py && pip2 install wpa_supplicant && pip2 install service_identity


#FROM kalilinux/kali-rolling
#COPY --from=builder 

#Enable ssh
RUN apt-get install -y ssh
RUN echo Port 2222 >> /etc/ssh/sshd_config && systemctl enable ssh 

CMD /bin/bash 

#RUN cd /root/tools &&  
