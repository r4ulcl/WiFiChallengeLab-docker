# Changelog WiFiChallengeLab

## Changelog: WiFiChallengeLab v2.5

### Added

* **Host-only RDP networks** (VirtualBox, VMware) and **Start/Stop Nzyme** desktop launchers
* **EAP-TLS identity-leak scenario** (hardened vs. leaking client certificates)
* **SIM/USIM AP** (`wifi-passpoint`, EAP-SIM/AKA/AKA') with **two EAP-AKA' clients** backed by a software HLR/AuC (`hlr_auc_gw` + Milenage, no physical SIM): a **leaking** one (permanent IMSI in the clear, any passive sniffer) and a **privacy-preserving** one (anonymous outer identity + pseudonym/fast-reauth: no passive leak, yet still surrenders its IMSI to a student-built evil-twin/rogue AP that actively requests the permanent identity)
* **Client-less PMKID AP** (`wifi-campus`): a lone WPA2-PSK BSSID (channel 7, no client on purpose) on radio `wlan31`. Capture the PMKID straight from the BSSID and crack the PSK offline (see `APs/PMKID_TESTING.md`)
* **WPA3 Cookie Guzzler airgeddon plugin** and **Vagrant audio support** (QEMU, VirtualBox)

### Modifications

* Consolidated **host networking on NetworkManager + systemd-resolved** (VirtualBox, VMware, QEMU, Hyper-V) and made the **Nzyme web UI reachable from other computers** (auto-detects host IP)
* Grew the **client radio pool 20 → 30** (`wlan40-69`, `radios=71`) and moved the **nzyme WIDS tap to `wlan70`**, freeing 10 slots for new scenarios
* Management **EAP-TLS AP now offers both TLS 1.3 and legacy TLS 1.2**; updated **wifi_db to v1.6**

### Bug Fixes

* **Networking:** fixed **DNS** on networks that block public resolvers and **AP internet sharing** (name-independent uplink detection)
* **Certificates:** added the missing `clientAuth` EKU to EAP-TLS client certs, made the CA RFC 5280-conformant, corrected the server cert subject/SAN, deduplicated them into a single generated set, and removed a stray `wget` in the AP `Dockerfile`
* **Web portals:** fixed PHP errors and session handling across the AP and client portals, plus `lab.php` not showing the username
* **MGT/EAP:** fixed a regional/locale error connecting to MGT (EAP relay) networks and the MSCHAP/GTC simulated logins using a MAC instead of the gateway IP; removed `ieee80211w` from the MSCHAPv2 relay client to match the AP; set **MFP optional** (`ieee80211w=1`) on the **WPA3 downgrade AP** so its SAE/WPA2-PSK transition mode works (mandatory MFP would block the WPA2-PSK downgrade path)
* **Build/misc:** made the **`ath_masker` build best-effort** (no more aborted image builds), removed the **hardcoded gcc/g++ 12**, fixed a **stale exit in the deauth-on-drop patch** and an **image-tag error in the challenge compose file**, fixed the **challenge flags** in `wlan_config_challenge`, and updated the **`pcapFilter.sh`** helper to the latest gist revision

### Miscellaneous Improvements

* **network self-heal** service to recover the uplink on boot; disabled **Debian automatic updates**
* Removed **email/PII and legacy Netscape fields** from generated certificates
* Reworked **healthchecks and compose files** across all variants; **hostapd per-SSID logs now capture stderr** (`2>&1`)
* Gave **each AP/client a distinct, stable signal** via per-radio **RSSI jitter (~±3 dB)** in the `mac80211_hwsim` driver (in-kernel, deterministic per radio, no per-beacon flicker) instead of a racy userspace `iw txpower` loop that hostapd overrode
* Ran **each MGT relay supplicant in its own loop** (a stall no longer blocks the others) and **backgrounded the client `fping` keepalive**
* Stopped the **GNOME session from locking on inactivity** (system-wide dconf no-idle-lock) for both **RDP** and **local desktop** sessions, so long-running attacks aren't interrupted
* Updated **OPEN_SOURCE_REFERENCES.md**

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