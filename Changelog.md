# Changelog WiFiChallengeLab

## Changelog: WiFiChallengeLab v2.5

### Modifications

* Consolidated host networking on **NetworkManager + systemd-resolved** for consistent internet, DNS and IP across VirtualBox, VMware, QEMU and Hyper-V
* Added **host-only networks** for RDP: `192.168.56.10` (VirtualBox) and `192.168.59.10` (VMware)
* Made the **Nzyme web UI reachable from other computers** (external URL auto-detects the host IP instead of `localhost`)
* Added **Start/Stop Nzyme** desktop launchers and helper scripts
* Added an **EAP-TLS identity-leak scenario**: a privacy-hardened client (`GLOBAL\GlobalAdmin`) alongside a leaking client (`GLOBAL\franz.ka`) whose certificate exposes username, email and organization details
* Management EAP-TLS AP now offers **both TLS 1.3 and legacy TLS 1.2**: TLS 1.3 clients keep the certificate encrypted, while a forced-TLS-1.2 client demonstrates the cleartext-certificate leak

### Bug Fixes

* Fixed **DNS** breaking on networks that block public resolvers (removed the immutable `/etc/resolv.conf` lock)
* Fixed **AP internet sharing** to use name-independent uplink detection
* Fixed **EAP-TLS client certificates** missing the `clientAuth` Extended Key Usage
* Made the **CA certificate RFC 5280-conformant** (`keyCertSign`/`cRLSign`) and corrected the **server certificate** subject/SAN to `radius.wifichallenge.com`

### Miscellaneous Improvements

* Added **network self-heal** service to recover the uplink via DHCP on boot
* Disabled **Debian automatic updates** (apt timers, unattended-upgrades, periodic config)
* Removed **email/PII and legacy Netscape fields** from generated certificates and hardened `createCert.sh` extensions (explicit `CA:FALSE`, critical `keyUsage`)

## Changelog: WiFiChallengeLab v2.4

### Modifications

* Added **OWE lab scenario** with new AP and client configs "force vuln" to dragonrain
* Configured 6GHz SAE network to challenge
* Introduced **decode_passwords** helper to generate `_CLEAR` vars from encoded passwords
* Added **OPEN_SOURCE_REFERENCES.md** and refreshed **README** (badges, docs, usage notes)
* Added more variables in ENV to web, aps, clients and nzyme. 
* New tools
  * WiFiChallenge/aircrack-ng with `--mfp`
  * vanhoefm/dragondrain-and-time
  * vanhoefm/ath_masker 
* Update website GUI 

### Bug Fixes

* Cleaned up **wlan_config** and env vars for APs, clients and relay
* Fixed **hostapd** and FreeRADIUS issues (quoting and password handling)
* Added missing **gettext-base** and other minor dependencies in client images

### Miscellaneous Improvements

* Enabled **Docker layer caching** and path based CI workflows
* Normalized line endings to **LF** and added `.gitattributes` for consistent diffs
* Workflows only generate the docker if there is any change


## Changelog: WiFiChallengeLab v2.3

### Modifications

* Switched base OS to **Debian 12** for improved stability and smaller image size
* Replaced **legacy MD5 authentication** with **FreeRADIUS** (@OscarAkaElvis #17)
* Added **Spanish keyboard** (GUI and keyboard, toggle with `CTRL + Space`)
* Improved **Vagrant file**, **cron responder loop**, and install scripts
* Recreated **RDP service** using **GNOME with XRDP**
* Removed `ctrl_interface` configuration for cleaner network setup

### Bug Fixes

* Fixed **autologin**, **DNS**, and **installTools** issues
* Resolved **background image** scaling problems
* Corrected **VBox Guest Additions** and **display configuration**
* Fixed **Vagrant loop** logging and tool installation order

### Miscellaneous Improvements

* Reduced image size and improved boot performance
* Simplified **tool installation** and reduced setup errors
* Enhanced **multilingual support** (ESP and ENG)
* General cleanup and performance optimizations

## Changelog: WiFiChallengeLab v2.2

### New Features:
- WPS attack with custom mac80211_hwsim
- EAP-MD5 AP and client vulnerable
- SAE 6GHZ network

### Modifications:
- Parche mac80211_hwsim kernel module to fix injection and WPS attack
- Update ubuntu to 22.04 and kernel version to 6.8
- Remove clear text flags and some passwords from code

### Bug Fixes:
- Allow not `[ver=1]` in MGT eap_users
- Fix OpenNDS TLS bypass and curl PSK only login if redirect to login

### Documentation:
- Update README.md change compose file line
- Add warning to avoid using the dockers outside a VM

### Miscellaneous Improvements:
- Encode flags PHP
- Reestructure Docker files and .env 
- Modify all script to ubuntu 22.04 instead of 20.04


## Changelog: WiFiChallengeLab v2.1

### New Features:
- **ARM Architecture Support**: Added Docker compatibility for ARM platforms (refer to the README for setup details).
- **Enhanced Docker Capabilities**: Optimized Dockerfile and `docker-compose` configurations for streamlined `nzyme` builds and improved health checks.
- **Upgraded Tools**:  
  - Fully integrated **Airgeddon** with all required dependencies.  
  - Added `wpa_gui` for advanced Wi-Fi management.  
  - Upgraded `hostapd-wpe` to version 2.11 and integrated the latest Aircrack-ng suite.  
  - Updated `hostapd-mana` to its latest release.  
  - Fixed issues with `EapHammer` and `hcxtools` for better functionality.

### Bug Fixes:
- Enhanced Docker stability, resolving issues with health checks and restart scripts.
- Unified TLS certificates and resolved Apache SSL configuration problems.
- Enabled **HTTPS** support for the access point web server.
- Improved installation scripts for key tools, including BeEF, Ruby, and SMBMap.
- Fixed PHP session handling and addressed minor web server-related bugs.
- Resolved anonymous login issues on MGT networks.
- Fixed MSCHAPv2 authentication errors for GTC users on MGT networks.

### Documentation:
- Updated the README with detailed VM creation steps and tool-specific updates, especially for ARM platforms.

### Miscellaneous Improvements:
- Removed `watchtower`, added healthchecks, and fixed resource allocation issues.  
- Improved HTML coding of the website 

This release introduces full Airgeddon integration, expanded ARM support, significant Docker enhancements, and crucial fixes to ensure improved stability and performance.

Special thanks to @OscarAkaElvis and @rsrdesarrollo for their invaluable contributions.

[Download WiFiChallengeLab v2.1](https://drive.proton.me/urls/Q4WPB23W7R#Qk4nxMH8Q4oQ)

---

## WiFiChallengeLab v2.0.4

### **Key Updates**
- Enhanced Docker configurations with updated CSS for a more intuitive user interface.
- Fixed broken APs to ensure successful connections.  
- Upgraded tools for better performance and compatibility.  
- Challenges now use web server flags instead of passwords for improved security and accessibility.

---

## WiFiChallengeLab v2.0.3

### **Key Updates**
- Introduced WEP attack scenarios.  
- Implemented minor fixes for improved stability.

---

## WiFiChallengeLab v2.0

The first Docker-based release of WiFiChallengeLab.  
For detailed updates and commit history, visit the [Full Changelog](https://github.com/r4ulcl/WiFiChallengeLab-docker/commits/v2.0).

To access version v1.0, visit: [WiFiChallengeLab v1.0](https://github.com/r4ulcl/WiFiChallengeLab/).

**Note**: The VMs are split into multiple parts. Ensure all parts (`001`, `002`, and `003`) are downloaded before unzipping.