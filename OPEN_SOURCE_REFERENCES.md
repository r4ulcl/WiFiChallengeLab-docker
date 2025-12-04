# Open Source References for WiFiChallengeLab-docker

Third-party projects used by the lab (Dockerfiles, vagrant/install.sh, and Attacker/installTools.sh).

| Project                            | Description                                                    | Source / Repo                                                          | License                          |
| ---------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------- | ---------------------------------|
| hostapd                            | Access Point service used across AP containers                 | https://w1.fi/hostapd/                                                 | BSD-3-Clause OR GPL-2.0          |
| wpa_supplicant                     | Wi-Fi supplicant used by client containers                     | https://w1.fi/wpa_supplicant/                                          | BSD-3-Clause                     |
| dnsmasq                            | DHCP/DNS for isolated lab segments                             | https://thekelleys.org.uk/dnsmasq/                                     | GPL-2.0                          |
| openNDS                            | Captive portal implementation in AP images                     | https://github.com/openNDS/openNDS                                     | GPL-2.0                          |
| GNU libmicrohttpd                  | Embedded HTTP daemon used by openNDS                           | https://www.gnu.org/software/libmicrohttpd/                            | LGPL-2.1                         |
| FreeRADIUS                         | RADIUS server for 802.1X/WPA-Enterprise scenarios              | https://github.com/FreeRADIUS/freeradius-server                        | GPL-2.0                          |
| Apache HTTP Server                 | Web server for captive portal and phishing pages               | https://github.com/apache/httpd                                        | Apache-2.0                       |
| PHP                                | Web application runtime for portal content                     | https://github.com/php/php-src                                         | PHP-3.01                         |
| nzyme (1.2.2)                      | Wireless IDS/monitoring stack                                  | https://github.com/nzymedefense/nzyme/tree/1.2.2?tab=License-1-ov-file | SSPL-1.0                         |
| PostgreSQL (14)                    | Database backing for nzyme telemetry                           | https://github.com/postgres/postgres                                   | PostgreSQL                       |
| Apache Maven                       | Java build tool used when building nzyme                       | https://github.com/apache/maven                                        | Apache-2.0                       |
| OpenJDK 11                         | Java runtime for nzyme                                         | https://github.com/openjdk/jdk11u                                      | GPL-2.0 with Classpath Exception |
| wifi_db                            | Handshake/credential database used by the attacker image       | https://github.com/r4ulcl/wifi_db                                      | GPL-3.0                          |
| EAP_buster                         | EAP credential attack toolkit (attacker image)                 | https://github.com/blackarrowsec/EAP_buster                            | MIT                              |
| crEAP                              | Enterprise Wi-Fi attack scripts (attacker image)               | https://github.com/Snizz/crEAP                                         | GPL-2.0                          |
| eaphammer                          | Evil twin framework (attacker image)                           | https://github.com/s0lst1c3/eaphammer                                  | GPL-3.0                          |
| hostapd-wpe                        | RADIUS/hostapd with WPE patches (attacker image)               | https://github.com/OpenSecurityResearch/hostapd-wpe                    | BSD-3-Clause OR GPL-2.0          |
| aircrack-ng                        | Wi-Fi auditing suite (attacker image)                          | https://github.com/aircrack-ng/aircrack-ng                             | GPL-2.0                          |
| arp-scan                           | ARP network scanner (attacker image)                           | https://github.com/royhills/arp-scan                                   | GPL-3.0                          |
| airgeddon                          | Wireless audit/attack framework (attacker image)               | https://github.com/v1s1t0r1sh3r3/airgeddon                             | GPL-3.0                          |
| airgeddon-plugins                  | Airgeddon plugin pack used by attacker installTools.sh         | https://github.com/OscarAkaElvis/airgeddon-plugins                     | GPL-3.0                          |
| dragon-drain-wpa3-airgeddon-plugin | WPA3 dragon-drain plugin pulled by attacker installTools.sh    | https://github.com/Janek79ax/dragon-drain-wpa3-airgeddon-plugin        | MIT                              |
| mdk4                               | Wi-Fi stress testing tool (attacker image)                     | https://github.com/aircrack-ng/mdk4                                    | GPL-3.0                          |
| wifipumpkin3                       | Rogue AP framework (attacker image)                            | https://github.com/P0cL4bs/wifipumpkin3                                | Apache-2.0                       |
| hostapd-mana                       | Hostapd fork with mana patches (attacker image)                | https://github.com/sensepost/hostapd-mana                              | BSD-3-Clause                     |
| reaver-wps-fork-t6x                | WPS attack tool (attacker image)                               | https://github.com/t6x/reaver-wps-fork-t6x                             | GPL-2.0                          |
| wpa_sycophant                      | EAP relay attack tool (attacker image)                         | https://github.com/sensepost/wpa_sycophant                             | BSD-3-Clause OR GPL-2.0          |
| berate_ap                          | EAP attack automation (attacker image)                         | https://github.com/sensepost/berate_ap                                 | BSD-2-Clause                     |
| air-hammer                         | PMKID/WPA attack toolkit (attacker image)                      | https://github.com/Wh1t3Rh1n0/air-hammer                               | Unknown                          |
| nmap                               | Network scanner (attacker image)                               | https://github.com/nmap/nmap                                           | NPSL                             |
| Wireshark / tshark                 | Packet capture/analysis (attacker image)                       | https://gitlab.com/wireshark/wireshark                                 | GPL-2.0                          |
| hcxtools / hcxdumptool             | Capture/convert WPA handshakes (attacker installTools.sh)      | https://github.com/ZerBea/hcxtools                                     | MIT                              |
| UnicastDeauth                      | Targeted deauth attack helper (attacker installTools.sh)       | https://github.com/mamatb/UnicastDeauth                                | CC BY-NC-SA 4.0                  |
| Hashcat & hashcat-utils            | Password cracker and helper utils (attacker installTools.sh)   | https://github.com/hashcat/hashcat                                     | MIT                              |
| John the Ripper (jumbo)            | Password cracker suite (attacker installTools.sh)              | https://github.com/openwall/john                                       | GPL-2.0                          |
| asleap                             | LEAP credential attack tool (attacker installTools.sh)         | https://github.com/joswr1ght/asleap                                    | GPL-2.0                          |
| bettercap                          | Network attack/monitoring framework (attacker installTools.sh) | https://github.com/bettercap/bettercap                                 | GPL-3.0                          |
| BeEF                               | Browser exploitation framework (attacker installTools.sh)      | https://github.com/beefproject/beef                                    | GPL-2.0                          |
| pixiewps                           | Offline WPS PIN recovery utility (airgeddon dependency)        | https://github.com/wiire/pixiewps                                      | GPL-3.0                          |
| crunch                             | Wordlist generator (airgeddon dependency)                      | https://sourceforge.net/projects/crunch-wordlist/                      | GPL-2.0                          |
| Ettercap (text)                    | Man-in-the-middle framework (airgeddon dependency)             | https://github.com/Ettercap/ettercap                                   | GPL-2.0                          |
| bully                              | WPS brute-force tool (airgeddon dependency)                    | https://github.com/aanarchyy/bully                                     | GPL-3.0                          |
| wifiphisher                        | Phishing/rogue AP toolkit (attacker installTools.sh)           | https://github.com/wifiphisher/wifiphisher                             | GPL-3.0                          |
| extra-phishing-pages               | Additional phishing templates for wifiphisher                  | https://github.com/wifiphisher/extra-phishing-pages                    | GPL-3.0                          |
| wifite2                            | Automated Wi-Fi attack orchestrator (attacker installTools.sh) | https://github.com/derv82/wifite2                                      | GPL-2.0                          |
| assless-chaps                      | WPA handshake cracking helper (attacker installTools.sh)       | https://github.com/sensepost/assless-chaps                             | Unknown                          |
| wacker                             | WPA Enterprise attack harness (attacker installTools.sh)       | https://github.com/blunderbuss-wctf/wacker                             | BSD-2-Clause                     |
| SecLists                           | Wordlists for usernames/passwords (attacker installTools.sh)   | https://github.com/danielmiessler/SecLists                             | MIT                              |
| pcapFilter.sh                      | Handshake capture filter helper script                         | https://gist.github.com/r4ulcl/f3470f097d1cd21dbc5a238883e79fb2        | Unknown                          |

Notes:
- This list is a work in progress
- The list may be out of date. If something is missing, you can open an issue or PR to update it
