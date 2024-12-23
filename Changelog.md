# Changelog WiFiChallengeLab

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