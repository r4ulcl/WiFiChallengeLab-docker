#!/usr/bin/env bash
#
# test_lab.sh - Deep end-to-end health/readiness test for WiFiChallengeLab-docker
#
# Verifies that the whole lab is actually working, not just "up":
#   - containers running, healthy, and not crash-looping
#   - kernel radios (host + ns-ap + ns-client), namespaces, veth links, internet
#   - every AP: interface, MAC, SSID, channel, security type (from its live
#     hostapd config), the exact hostapd process, its web server, AND its hostapd
#     log (AP-ENABLED came up, no bring-up errors) + live count of associated STAs
#   - freeradius: process, 1812/udp, and "Ready to process requests" in its log
#   - config-template substitution actually ran (no leftover ${VARS})
#   - server certificates for the Enterprise (MGT/TLS) challenges
#   - every client: interface, the exact supplicant process, live association to
#     the expected SSID, a DHCP lease, AND its supplicant log (has it ever
#     CONNECTED / had EAP-SUCCESS - robust for the MGT clients that rotate)
#   - startup completion: the "ALL SET" marker + fatal errors in container stdout
#   - nzyme WIDS: web, tap radio (monitor mode), postgres, migrated schema, log
#   - attacker toolkit + monitor-mode capability
#   - client-less PMKID target (roam APs): the mac80211_hwsim ACK patch is loaded
#     and hcxdumptool is new enough for -w/--rds; with --scan, a live end-to-end
#     PMKID capture that also proves the hostapd msg1 PMKID patch
#   - a per-challenge infra-readiness matrix (only with --challenges; never shown
#     in a normal run, and it lists no objectives/techniques - just up/down)
#
# Logs are read via `docker exec ... cat /root/logs/*` (they're also bind-mounted
# on the host at ./logsAP, ./logsClient, ./nzyme/nzyme-logs/logs).
#
# The expected inventory (SSIDs, channels, MACs) is read live from ./wlan_config
# so this test cannot drift from the lab definition.
#
# Run it ON THE LAB HOST/VM (the box that runs `docker compose up`); it reaches
# into the containers with `docker exec`.
#
# Usage:
#   ./test_lab.sh                 # full check
#   ./test_lab.sh --quick         # skip slow network probes (web, associations, DHCP, internet)
#   ./test_lab.sh --scan          # also scan over the air from an attacker radio (SCAN_IFACE, default wlan0)
#                                 # and run a live client-less PMKID capture on the roam APs
#   ./test_lab.sh --no-tools      # skip the attacker toolkit inventory
#   ./test_lab.sh --challenges    # only print the per-challenge infra-readiness matrix
#                                 # (opt-in; a normal run never prints challenge rows)
#   ./test_lab.sh -h | --help
#
# Exit code: 0 if no FAIL, 1 otherwise.

set -u

########################################
# Options
########################################
DO_SCAN=0; DO_TOOLS=1; DO_DEEP_NET=1; ONLY_CHALLENGES=0
SCAN_IFACE="${SCAN_IFACE:-wlan0}"
for a in "$@"; do
  case "$a" in
    --scan)       DO_SCAN=1 ;;
    --no-tools)   DO_TOOLS=0 ;;
    --quick)      DO_DEEP_NET=0 ;;
    --challenges) ONLY_CHALLENGES=1 ;;
    -h|--help)    sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "Unknown option: $a (see --help)"; exit 2 ;;
  esac
done

########################################
# Output helpers + counters
########################################
if [ -t 1 ]; then
  R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[34m'; C=$'\e[36m'; BOLD=$'\e[1m'; N=$'\e[0m'
else R=""; G=""; Y=""; B=""; C=""; BOLD=""; N=""; fi
PASS=0; FAIL=0; WARN=0
declare -a FAILED_ITEMS=()
pass() { PASS=$((PASS+1)); printf "  ${G}[PASS]${N} %s\n" "$1"; }
# warn/fail take an optional 2nd arg: a copy-pasteable command to dig deeper.
# It's printed dimmed under the message so you can investigate the WARN at once.
warn() { WARN=$((WARN+1)); printf "  ${Y}[WARN]${N} %s\n" "$1"; [ -n "${2:-}" ] && printf "         ${C}\xE2\x86\xB3 %s${N}\n" "$2"; return 0; }
fail() { FAIL=$((FAIL+1)); FAILED_ITEMS+=("$1"); printf "  ${R}[FAIL]${N} %s\n" "$1"; [ -n "${2:-}" ] && printf "         ${C}\xE2\x86\xB3 %s${N}\n" "$2"; return 0; }
info() { printf "  ${C}[..]${N}  %s\n" "$1"; }
section() { printf "\n${BOLD}${B}== %s ==${N}\n" "$1"; }
check() { local l="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$l"; else fail "$l"; fi; }

########################################
# Containers + exec helpers
########################################
APS_C="WiFiChallengeLab-APs"; CLI_C="WiFiChallengeLab-Clients"
NZYME_C="WiFiChallengeLab-nzyme"; DB_C="WiFiChallengeLab-nzyme-db"
ATT_C="WiFiChallengeLab-Attacker"
HAVE_DOCKER=0; command -v docker >/dev/null 2>&1 && HAVE_DOCKER=1
# Use `bash -c` (NOT -lc): a login shell sources /etc/profile + rc files, whose
# banners/MOTD would land on stdout and corrupt the awk/grep parsing below.
dexec()  { docker exec "$1" bash -c "$2" 2>/dev/null; }
ns_ap()  { docker exec "$APS_C" ip netns exec ns-ap    bash -c "$1" 2>/dev/null; }
ns_cli() { docker exec "$CLI_C" ip netns exec ns-client bash -c "$1" 2>/dev/null; }
container_running() { [ "$HAVE_DOCKER" = 1 ] && [ "$(docker inspect -f '{{.State.Running}}' "$1" 2>/dev/null)" = "true" ]; }
container_health()  { docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}none{{end}}' "$1" 2>/dev/null; }
container_restarts(){ docker inspect -f '{{.RestartCount}}' "$1" 2>/dev/null; }

########################################
# Load expected inventory from wlan_config
########################################
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# The wlan_config files live in the repo root. This script may sit in the root or
# in utils/, so look in SCRIPT_DIR first and fall back to its parent (repo root).
CONF_DIR="$SCRIPT_DIR"
[ -f "$CONF_DIR/wlan_config" ] || { [ -f "$SCRIPT_DIR/../wlan_config" ] && CONF_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; }
# The lab can be launched with ./wlan_config (production) OR ./wlan_config_challenge
# (docker-compose-challenge*.yml), which have different SSIDs/MACs/channels. Hard-
# wiring to one would false-warn ~15 APs on the other. So auto-detect: read the
# live AP SSIDs and source whichever candidate file matches more of them.
essid_vals() { sed -n "s/^ESSID_[A-Za-z0-9_]*='\([^']*\)'.*/\1/p" "$1" 2>/dev/null | sort -u; }
LIVE_SSIDS=""
container_running "$APS_C" && LIVE_SSIDS="$(ns_ap "iw dev 2>/dev/null | sed -n 's/^[[:space:]]*ssid //p'" | sort -u)"
WLAN_CONF="$CONF_DIR/wlan_config"; CONF_KIND="production (wlan_config)"
if [ -n "$LIVE_SSIDS" ] && [ -f "$CONF_DIR/wlan_config_challenge" ]; then
  m_prod="$(comm -12 <(essid_vals "$CONF_DIR/wlan_config") <(printf '%s\n' "$LIVE_SSIDS") | grep -c .)"
  m_chal="$(comm -12 <(essid_vals "$CONF_DIR/wlan_config_challenge") <(printf '%s\n' "$LIVE_SSIDS") | grep -c .)"
  if [ "${m_chal:-0}" -gt "${m_prod:-0}" ]; then WLAN_CONF="$CONF_DIR/wlan_config_challenge"; CONF_KIND="challenge (wlan_config_challenge)"; fi
fi
HAVE_CONF=0
if [ -f "$WLAN_CONF" ]; then
  # shellcheck disable=SC1090
  set -a; . "$WLAN_CONF" >/dev/null 2>&1 && HAVE_CONF=1; set +a
fi
val() { local v="${1:-}"; [ -n "$v" ] && printf '%s' "${!v:-}"; }

# AP rows: label|wlan|ESSID_var|CHAN_var|MAC_var|ip|type|confpath
# MAC_var empty => random MAC (ISP routers), don't verify. type drives the
# security marker we expect to find in the running hostapd config.
AP_ROWS=(
  "OPN guest        |wlan10|ESSID_OPN|CHANNEL_OPN|MAC_OPN|192.168.10|OPN|open/hostapd_open.conf"
  "OPN hidden       |wlan26|ESSID_OPN_HIDDEN|CHANNEL_OPN_HIDDEN|MAC_OPN_HIDDEN|192.168.16|OPNHID|open/hostapd_open_hidden.conf"
  "WEP old          |wlan11|ESSID_WEP|CHANNEL_WEP|MAC_WEP|192.168.1|WEP|wep/hostapd_wep.conf"
  "PSK mobile       |wlan12|ESSID_PSK|CHANNEL_PSK|MAC_PSK|192.168.2|PSK|psk/hostapd_wpa.conf"
  "PSK event        |wlan13|ESSID_WPS|CHANNEL_WPS|MAC_WPS|192.168.3|PSK|psk/hostapd_wps.conf"
  "PSK campus       |wlan31|ESSID_ROAM|CHANNEL_ROAM1|MAC_ROAM1|192.168.21|PSK|psk/hostapd_pmkid.conf"
  "MGT corp         |wlan15|ESSID_MGT|CHANNEL_MGT|MAC_MGT|192.168.5|MGT|mgt/hostapd_wpe.conf"
  "MGT corp #2      |wlan16|ESSID_MGT2|CHANNEL_MGT2|MAC_MGT2|192.168.5|MGT|mgt/hostapd_wpe2.conf"
  "MGT regional     |wlan17|ESSID_MGT_RELAY|CHANNEL_MGT_RELAY|MAC_MGT_RELAY|192.168.7|MGT|mgt/hostapd_wpe_relay.conf"
  "MGT reg tablets  |wlan28|ESSID_MGT_RELAY_TABLETS|CHANNEL_MGT_RELAY_TABLETS|MAC_MGT_RELAY_TABLETS|192.168.18|MGT|mgt/hostapd_wpe_relay_tablets.conf"
  "MGT global       |wlan18|ESSID_MGT_TLS|CHANNEL_MGT_TLS|MAC_MGT_TLS|192.168.8|MGT|mgt/hostapd_wpe_tls.conf"
  "MGT legacy       |wlan27|ESSID_MGT_MD5|CHANNEL_MGT_MD5|MAC_MGT_MD5|192.168.17|MGT|mgt/hostapd_wpe_md5.conf"
  "SIM passpoint    |wlan19|ESSID_MGT_SIM|CHANNEL_MGT_SIM|MAC_MGT_SIM|192.168.9|MGT|mgt/hostapd_wpe_sim.conf"
  "SAE management   |wlan24|ESSID_BRUTEFORCE|CHANNEL_BRUTEFORCE|MAC_BRUTEFORCE|192.168.14|SAE|wpa3/hostapd_bruteforce.conf"
  "SAE IT           |wlan25|ESSID_DOWNGRADE|CHANNEL_DOWNGRADE|MAC_DOWNGRADE|192.168.15|SAE|wpa3/hostapd_downgrade.conf"
  "SAE engineering  |wlan29|ESSID_6GHZ|CHANNEL_6GHZ|MAC_6GHZ|192.168.19|SAE|wpa3/hostapd_6ghz.conf"
  "OWE gratis       |wlan30|ESSID_OWE|CHANNEL_OWE|MAC_OWE|192.168.20|OWE|owe/hostapd_owe.conf"
  "ISP MOVISTAR     |wlan20|ESSID_OTHER0|CHANNEL_OTHER0||192.168.30|PSK|psk/hostapd_other0.conf"
  "ISP WIFI-JUAN    |wlan21|ESSID_OTHER1|CHANNEL_OTHER1||192.168.11|PSK|psk/hostapd_other1.conf"
  "ISP vodafone     |wlan22|ESSID_OTHER2|CHANNEL_OTHER2||192.168.12|PSK|psk/hostapd_other2.conf"
  "ISP MiFibra      |wlan23|ESSID_OTHER3|CHANNEL_OTHER3||192.168.13|PSK|psk/hostapd_other3.conf"
)
EXPECTED_AP_PROCS=23

# Client rows: wlan|expected_ESSID_var|supplicant_conf|associates(yes/no)|logfile
# logfile is the supplicant output under /root/logs/ (naming is not derivable
# from the conf name, so it's listed explicitly; see Clients/config/startClients.sh).
CLIENT_ROWS=(
  "40|ESSID_MGT|wpa_mschapv2.conf|yes|supplicantMSCHAP.log"
  "41|ESSID_MGT|wpa_gtc.conf|yes|supplicantGTC.log"
  "42|ESSID_MGT_TLS|wpa_TLS.conf|yes|supplicantTLS.log"
  "43|ESSID_PSK|wpa_psk.conf|yes|supplicantPSK.log"
  "44|ESSID_PSK|wpa_psk.conf|yes|supplicantPSK2.log"
  "45|ESSID_PSK_NOAP|wpa_psk_noAP.conf|no|supplicantNoAP.log"
  "46|ESSID_PSK_NOAP|wpa_psk_noAP.conf|no|supplicantNoAP2.log"
  "47|ESSID_OPN|open_supplicant1.conf|yes|supplicantOpen1.log"
  "48|ESSID_OPN|open_supplicant2.conf|yes|supplicantOpen2.log"
  "49|ESSID_OPN|open_supplicant3.conf|yes|supplicantOpen3.log"
  "50|ESSID_MGT_RELAY|wpa_mschapv2_relay.conf|yes|supplicantMSCHAP_relay.log"
  "51||wpa_TLS_phishing.conf|no|supplicantTLS_phishing.log"
  "52|ESSID_DOWNGRADE|downgrade_psk.conf|yes|supplicantWPA3Downgrade.log"
  "53|ESSID_MGT_MD5|wpa_md5.conf|yes|supplicantMD5.log"
  "54|ESSID_MGT_RELAY_TABLETS|wpa_mschapv2_relay_tabletsW.conf|yes|supplicantMSCHAP_relay_tabletsW.log"
  "55|ESSID_MGT_RELAY_TABLETS|wpa_mschapv2_relay_tablets.conf|yes|supplicantMSCHAP_relay_tablets.log"
  "56|ESSID_WEP|wep.conf|yes|supplicantWEP.log"
  "57|ESSID_OWE|owe.conf|yes|supplicantOWE.log"
  "58|ESSID_MGT_TLS|wpa_TLS_leak.conf|yes|supplicantTLS_leak.log"
  "59|ESSID_MGT_SIM|wpa_sim_leak.conf|yes|supplicantSIM_leak.log"
  "60|ESSID_MGT_SIM|wpa_sim.conf|yes|supplicantSIM.log"
  "61|ESSID_MGT_SIM|wpa_sim_rogue.conf|yes|supplicantSIM_rogue.log"
  "62||randmac.conf|no|supplicantRANDMAC.log"
)
EXPECTED_CLIENT_PROCS=21

########################################
# Attacker toolkit
########################################
TOOLS=(
  "aircrack-ng|command -v aircrack-ng"      "airodump-ng|command -v airodump-ng"
  "aireplay-ng|command -v aireplay-ng"      "airdecap-ng|command -v airdecap-ng"
  "airmon-ng|command -v airmon-ng"          "besside-ng|command -v besside-ng"
  "hcxdumptool|command -v hcxdumptool"      "hcxpcapngtool|command -v hcxpcapngtool"
  "hcxhash2cap|command -v hcxhash2cap"      "hashcat|command -v hashcat"
  "john|command -v john || test -x /root/tools/john/run/john"
  "tshark|command -v tshark"                "wpa_supplicant|command -v wpa_supplicant"
  "openssl|command -v openssl"
  "hostapd-wpe|command -v hostapd-wpe || test -x /usr/sbin/hostapd-wpe"
  "hostapd-mana|command -v hostapd-mana"    "eaphammer|test -e /root/tools/eaphammer/eaphammer"
  "EAP_buster|test -e /root/tools/EAP_buster/EAP_buster.sh"
  "air-hammer|test -e /root/tools/air-hammer/air-hammer.py"
  "berate_ap|test -d /root/tools/berate_ap" "responder|command -v responder || test -d /root/tools/eaphammer/settings"
  "asleap|command -v asleap"                "bettercap|command -v bettercap"
  "wifite|command -v wifite || command -v wifite2"
  "airgeddon|test -e /root/tools/airgeddon/airgeddon.sh"
  "mdk4|command -v mdk4"                     "reaver|command -v reaver"
  "bully|command -v bully"                   "wacker|test -e /root/tools/wacker/wacker.py"
  "dragondrain|command -v dragondrain"       "wpa_sycophant|test -d /root/tools/wpa_sycophant"
  "assless-chaps|test -d /root/tools/assless-chaps"
  "wifiphisher|command -v wifiphisher || test -d /root/tools/wifiphisher"
  "wifipumpkin3|command -v wifipumpkin3"     "crEAP|test -e /root/tools/crEAP/crEAP.py"
  "wifi_db|test -e /root/tools/wifi_db/wifi_db.py"
  "arp-scan|command -v arp-scan"             "macchanger|command -v macchanger"
  "nmap|command -v nmap"
  "wordlist rockyou|test -s /usr/share/wordlists/rockyou.txt.gz || test -s /usr/share/wordlists/rockyou.txt || test -s /root/rockyou-top100000.txt"
)
TOOL_CTX="host"; container_running "$ATT_C" && TOOL_CTX="attacker"
tool_run() { if [ "$TOOL_CTX" = attacker ]; then docker exec "$ATT_C" bash -lc "$1" >/dev/null 2>&1; else bash -lc "$1" >/dev/null 2>&1; fi; }

# extract the per-interface block for wlanN from an `iw dev` dump
iw_block() { awk -v w="$2" '$1=="Interface"{c=$2} c==w{print} c!=w && $1=="Interface" && s{exit} c==w{s=1}' <<<"$1"; }

########################################
# Global readiness flags (used by matrix)
########################################
FREERADIUS_OK=0; DNSMASQ_OK=0

if [ "$ONLY_CHALLENGES" = 0 ]; then
########################################
# 0. Prerequisites
########################################
section "Prerequisites"
if [ "$HAVE_DOCKER" = 1 ]; then pass "docker CLI present"; else fail "docker CLI not found (run on the lab host)"; fi
if [ "$HAVE_CONF" = 1 ]; then pass "inventory loaded: ${CONF_KIND} (auto-detected from live SSIDs)"; else warn "wlan_config not found next to script - SSID/MAC checks limited"; fi

########################################
# 1. Containers
########################################
section "Containers"
for pair in "$APS_C:aps" "$CLI_C:clients" "$NZYME_C:nzyme" "$DB_C:db"; do
  c="${pair%%:*}"
  if container_running "$c"; then
    h="$(container_health "$c")"; rc="$(container_restarts "$c")"
    case "$h" in
      healthy)   pass "$c running + healthy" ;;
      none)      pass "$c running (no healthcheck)" ;;
      starting)  warn "$c running, health=starting (still in start_period)" ;;
      unhealthy) fail "$c running but health=UNHEALTHY" ;;
      *)         warn "$c running (health: $h)" ;;
    esac
    [ "${rc:-0}" -gt 3 ] 2>/dev/null && warn "$c has restarted ${rc} times (crash-looping?)" \
      "docker logs $c 2>&1 | tail -40"
  else fail "$c is not running" "docker ps -a --filter name=$c --format '{{.Names}} {{.Status}}' ; docker logs $c 2>&1 | tail -40"; fi
done

########################################
# 2. Kernel radios, namespaces, connectivity
########################################
section "Kernel radios, namespaces, connectivity"
if container_running "$APS_C"; then
  # hwsim creates all ~61 phys in the host netns, then the lab moves the AP phys
  # into ns-ap and the client phys into ns-client. A wiphy's /sys/class/ieee80211
  # entry follows it into its netns, so the host default ns only sees the handful
  # that stay there (attacker wlan0-5 + nzyme wlan70 ~= 8). The AP/Client/nzyme
  # containers all run network_mode:host, so their default ns IS the host ns -
  # counting them would double-count. The only *distinct* namespaces are the host
  # ns plus the ns-ap / ns-client sub-namespaces; sum exactly those three.
  PHYS_CMD='ls -d /sys/class/ieee80211/phy* 2>/dev/null | wc -l'
  R_HOST=0; R_AP=0; R_CLI=0
  R_HOST="$(bash -c "$PHYS_CMD" 2>/dev/null)"; R_HOST="${R_HOST//[!0-9]/}"
  R_AP="$(ns_ap  "$PHYS_CMD")";  R_AP="${R_AP//[!0-9]/}"
  R_CLI="$(ns_cli "$PHYS_CMD")"; R_CLI="${R_CLI//[!0-9]/}"
  RADIOS=$(( ${R_HOST:-0} + ${R_AP:-0} + ${R_CLI:-0} ))
  if [ "$RADIOS" -ge 60 ]; then pass "mac80211_hwsim radios: ${RADIOS} phys (host ${R_HOST:-0} + ns-ap ${R_AP:-0} + ns-client ${R_CLI:-0}, expected ~61)"
  else fail "hwsim radios: ${RADIOS} (host ${R_HOST:-0} + ns-ap ${R_AP:-0} + ns-client ${R_CLI:-0}, expected ~61) - module not fully loaded/distributed" \
    "lsmod | grep mac80211_hwsim ; ls /sys/class/ieee80211 ; docker exec $APS_C ip netns exec ns-ap ls /sys/class/ieee80211"; fi
  check "netns ns-ap exists" bash -c "docker exec $APS_C ip netns list 2>/dev/null | grep -qw ns-ap"
  if ns_ap 'ip -o addr show vpeer1 2>/dev/null | grep -q 10.200.1.2'; then pass "ns-ap veth uplink 10.200.1.2 up"
  else warn "ns-ap veth uplink (vpeer1/10.200.1.2) not found"; fi
  if [ "$DO_DEEP_NET" = 1 ]; then
    if ns_ap 'ping -c1 -W2 8.8.8.8 >/dev/null 2>&1'; then pass "ns-ap has internet (masquerade works)"
    else warn "ns-ap has no internet - offline lab or NAT not set (ok if host is offline)" \
      "docker exec $APS_C ip netns exec ns-ap ip route ; iptables -t nat -L POSTROUTING -n"; fi
  fi
fi
if container_running "$CLI_C"; then
  check "netns ns-client exists" bash -c "docker exec $CLI_C ip netns list 2>/dev/null | grep -qw ns-client"
  ns_cli 'ip -o addr show vpeer2 2>/dev/null | grep -q 10.200.2.2' && pass "ns-client veth uplink 10.200.2.2 up" || warn "ns-client veth uplink not found"
fi

########################################
# 3. Access Points
########################################
section "Access Points (ns-ap)"
if container_running "$APS_C"; then
  IWDEV="$(ns_ap 'iw dev 2>/dev/null')"
  APPS="$(ns_ap 'pgrep -a host_aps_apd 2>/dev/null')"
  CONFDUMP="$(ns_ap 'grep -rHE "^(ssid|wpa_key_mgmt|wep_key0|owe_transition|key_mgmt)" /root/open /root/psk /root/wpa3 /root/mgt /root/wep /root/owe 2>/dev/null')"
  LEFTOVER="$(ns_ap 'grep -rl "\${" /root/open /root/psk /root/wpa3 /root/mgt /root/wep /root/owe /var/www/html 2>/dev/null')"
  # Per-AP hostapd log health: AP-ENABLED means the radio actually came up; the
  # error regex catches fatal bring-up failures (stderr is not captured, so
  # corroborate with process liveness). Live station counts come from STA_DUMP
  # below. Logs live on the container fs -> plain docker exec cat.
  HAPD_STAT="$(dexec "$APS_C" 'for f in /root/logs/hostapd_*.log; do [ -f "$f" ] || continue;
    b=$(basename "$f" .log);
    en=$(grep -c "AP-ENABLED" "$f" 2>/dev/null);
    er=$(grep -ciE "Could not|Interface initialization failed|Failed to (enable|start|set)|invalid channel|does not support|no such device" "$f" 2>/dev/null);
    echo "$b en=${en:-0} er=${er:-0}"; done')"
  # Live association snapshot from the AP side: how many stations are associated
  # to each AP interface right now (the authoritative "clients connected" signal).
  STA_DUMP="$(ns_ap 'for w in $(iw dev 2>/dev/null | awk "/Interface/{print \$2}"); do
    c=$(iw dev "$w" station dump 2>/dev/null | grep -c "^Station"); echo "$w ${c:-0}"; done')"
  hapd_field() { awk -v b="hostapd_$1" -v k="$2" '$1==b{for(i=2;i<=NF;i++){split($i,a,"=");if(a[1]==k)print a[2]}}' <<<"$HAPD_STAT"; }
  sta_count()  { awk -v w="$1" '$1==w{print $2; exit}' <<<"$STA_DUMP"; }
  AP_STA_TOTAL=0; AP_ENABLED_OK=0

  n_ap="$(grep -c . <<<"$APPS")"; [ -z "$APPS" ] && n_ap=0
  if [ "$n_ap" -ge "$EXPECTED_AP_PROCS" ]; then pass "host_aps_apd processes: $n_ap (expected $EXPECTED_AP_PROCS)"
  elif [ "$n_ap" -ge 18 ]; then warn "host_aps_apd processes: $n_ap (expected $EXPECTED_AP_PROCS; 1 down within tolerance)"
  else fail "host_aps_apd processes: $n_ap (expected $EXPECTED_AP_PROCS) - APs missing"; fi

  if ns_ap 'pgrep -x freeradius >/dev/null'; then FREERADIUS_OK=1; pass "freeradius running"
    if ns_ap 'ss -lun 2>/dev/null | grep -q ":1812" || netstat -lun 2>/dev/null | grep -q ":1812"'; then pass "freeradius listening on 1812/udp"
    else warn "freeradius up but 1812/udp not seen listening" \
      "docker exec $APS_C ip netns exec ns-ap ss -lunp | grep 1812"; fi
    # Process up != usable: only after "Ready to process requests" are the EAP
    # module and server cert loaded. A bad cert/eap config leaves it up but dead.
    if dexec "$APS_C" 'grep -q "Ready to process requests" /var/log/freeradius/radius.log 2>/dev/null'; then
      pass "freeradius initialized (EAP/cert loaded, ready to process requests)"
    else warn "freeradius up but 'Ready to process requests' not in radius.log - EAP/cert init may have failed" \
      "docker exec $APS_C tail -40 /var/log/freeradius/radius.log"; fi
    # Count real errors only: exclude the one-time BlastRADIUS (CVE-2024-3596)
    # startup notices (limit_proxy_state / require_message_authenticator / the
    # !!!! banner) which freeradius logs at "Error:" level but are benign.
    RADBENIGN='BlastRADIUS|Proxy-State|Message-Authenticator|limit_proxy_state|require_message_authenticator|Error: !+'
    RADERR="$(dexec "$APS_C" "grep -iE 'Error|Failed|rlm_eap: .*fail' /var/log/freeradius/radius.log 2>/dev/null | grep -cvE '$RADBENIGN'")"; RADERR="${RADERR//[!0-9]/}"
    [ "${RADERR:-0}" -gt 0 ] && warn "freeradius radius.log has ${RADERR} non-benign error/fail line(s) - inspect for EAP issues" \
      "docker exec $APS_C grep -niE 'Error|Failed|rlm_eap: .*fail' /var/log/freeradius/radius.log | grep -vE '$RADBENIGN'   # BlastRADIUS notices already excluded; 'Login incorrect' lines are expected, 'Failed to load/initialize' = real"
  else fail "freeradius NOT running - the EAP challenge that depends on it will fail (other MGT APs use hostapd's embedded EAP, unaffected)"; fi
  check "apache serves /login.php" bash -c "docker exec $APS_C ip netns exec ns-ap curl -fs -o /dev/null http://localhost/login.php"
  check "opennds captive portal on :8080" bash -c "docker exec $APS_C ip netns exec ns-ap curl -s -o /dev/null http://localhost:8080"
  if ns_ap 'pgrep -x dnsmasq >/dev/null'; then DNSMASQ_OK=1; pass "dnsmasq (captive DHCP/DNS) running"
  else warn "dnsmasq not running - OPN captive-portal DHCP may fail" \
    "docker exec $APS_C tail -30 /root/logs/cronAPs.log   # dnsmasq is (re)spawned by cronAPs.sh"; fi

  if [ -z "$LEFTOVER" ]; then pass "config templates fully substituted (no leftover \${VARS})"
  else fail "unsubstituted \${VARS} left in: $(tr '\n' ' ' <<<"$LEFTOVER")"; fi

  if ns_ap 'ls /root/certs/*.pem /root/certs/*.crt >/dev/null 2>&1 || ls /root/mgt/certs/* >/dev/null 2>&1'; then
    pass "server certificates present for Enterprise APs"
    # Presence of the server cert's identity fields is validated implicitly by the
    # openssl checks below; the field values themselves are not printed (they are
    # part of a challenge answer).
    if ns_ap 'for c in /root/certs/*.pem /root/certs/*.crt; do [ -f "$c" ] && openssl x509 -in "$c" -noout -subject >/dev/null 2>&1 && exit 0; done; exit 1'; then
      pass "server cert parses (subject/identity fields readable)"
    else warn "server cert present but not parseable by openssl - MGT/PEAP/TLS auth may fail" \
      "docker exec $APS_C ip netns exec ns-ap sh -c 'for c in /root/certs/*.pem /root/certs/*.crt; do openssl x509 -in \"\$c\" -noout -subject; done'"; fi
    # Cert chain + validity: a CA-mismatched or expired cert leaves freeradius/
    # hostapd "ready" yet every EAP-TLS/PEAP auth fails silently. Verify the CA
    # signed server+client certs, the server cert is in its validity window, and
    # the client cert/key pair matches.
    if dexec "$APS_C" 'test -f /root/certs/ca.crt && test -f /root/certs/server.crt'; then
      dexec "$APS_C" 'openssl verify -CAfile /root/certs/ca.crt /root/certs/server.crt >/dev/null 2>&1' \
        && pass "server cert verifies against CA" \
        || fail "server cert does NOT verify against ca.crt - MGT/PEAP/TLS auth will fail" \
             "docker exec $APS_C openssl verify -CAfile /root/certs/ca.crt /root/certs/server.crt"
      if dexec "$APS_C" 'openssl x509 -in /root/certs/server.crt -noout -checkend 0 >/dev/null 2>&1'; then
        dexec "$APS_C" 'openssl x509 -in /root/certs/server.crt -noout -checkend 2592000 >/dev/null 2>&1' \
          && pass "server cert valid (>30 days remaining)" \
          || warn "server cert expires within 30 days - regenerate with ./generateCerts.sh" \
               "docker exec $APS_C openssl x509 -in /root/certs/server.crt -noout -enddate"
      else fail "server cert EXPIRED - all EAP-TLS/PEAP auth fails" \
             "docker exec $APS_C openssl x509 -in /root/certs/server.crt -noout -dates"; fi
      if dexec "$APS_C" 'test -f /root/certs/client.crt'; then
        dexec "$APS_C" 'openssl verify -CAfile /root/certs/ca.crt /root/certs/client.crt >/dev/null 2>&1' \
          && pass "client cert verifies against CA (EAP-TLS)" \
          || warn "client.crt does not verify against ca.crt" \
               "docker exec $APS_C openssl verify -CAfile /root/certs/ca.crt /root/certs/client.crt"
      fi
    fi
  else warn "no server certs under /root/certs - MGT challenges may fail"; fi

  # EAP-TLS 1.3 (secure client wlan42) needs hostapd linked against
  # OpenSSL >=1.1.1; a GnuTLS/old-OpenSSL build silently ignores the AP's
  # tls_flags=[ENABLE-TLSv1.3] and every TLS-1.3 handshake fails. Static guard;
  # the live behavioural check is in the Clients section.
  if dexec "$APS_C" 'ldd "$(command -v host_aps_apd)" 2>/dev/null | grep -qi libssl'; then
    pass "hostapd (host_aps_apd) linked against OpenSSL - EAP-TLS 1.3 capable"
  else warn "hostapd not linked against OpenSSL libssl - EAP-TLS 1.3 likely unavailable (rebuild with CONFIG_TLSV13=y)" \
    "docker exec $APS_C ldd \$(command -v host_aps_apd) | grep -iE 'ssl|gnutls'"; fi

  for row in "${AP_ROWS[@]}"; do
    IFS='|' read -r label wlan ev cv mv ip typ conf <<<"$row"
    label="$(echo "$label"|xargs)"; typ="$(echo "$typ"|xargs)"
    essid="$(val "$ev")"; chan="$(val "$cv")"; mac="$(val "$mv")"
    if ! grep -qw "$wlan" <<<"$IWDEV"; then fail "$label [$wlan] interface MISSING in ns-ap"; continue; fi
    blk="$(iw_block "$IWDEV" "$wlan")"
    seen_ssid="$(awk '/ssid /{print $2; exit}' <<<"$blk")"
    seen_chan="$(awk '/channel /{print $2; exit}' <<<"$blk")"
    seen_mac="$(awk '/addr /{print $2; exit}' <<<"$blk")"
    problems=()
    grep -q "/$conf\b" <<<"$APPS" || problems+=("hostapd '$conf' not running")
    [ -n "$chan" ] && [ -n "$seen_chan" ] && [ "$seen_chan" != "$chan" ] && problems+=("ch $seen_chan!=$chan")
    if [ "$typ" != "OPNHID" ] && [ -n "$essid" ] && [ -n "$seen_ssid" ] && [ "$seen_ssid" != "$essid" ]; then
      problems+=("ssid '$seen_ssid'!='$essid'"); fi
    if [ -n "$mac" ] && [ -n "$seen_mac" ] && [ "${seen_mac,,}" != "${mac,,}" ]; then problems+=("mac $seen_mac!=$mac"); fi
    cfgline="$(grep "/$conf:" <<<"$CONFDUMP")"
    case "$typ" in
      MGT) grep -qi "WPA-EAP" <<<"$cfgline" || problems+=("no WPA-EAP in cfg") ;;
      SAE) grep -qi "SAE"     <<<"$cfgline" || problems+=("no SAE in cfg") ;;
      OWE) grep -qi "OWE"     <<<"$cfgline" || problems+=("no OWE in cfg") ;;
      PSK) grep -qi "WPA-PSK" <<<"$cfgline" || problems+=("no WPA-PSK in cfg") ;;
      WEP) grep -qi "wep_key0" <<<"$cfgline" || problems+=("no wep_key0 in cfg") ;;
    esac
    # hostapd log health for this AP: derive the log basename from the conf name
    # (open/hostapd_open.conf -> hostapd_open.log).
    logbase="$(basename "$conf" .conf)"; logbase="${logbase#hostapd_}"
    en="$(hapd_field "$logbase" en)"; er="$(hapd_field "$logbase" er)"
    sta="$(sta_count "$wlan")"; sta="${sta:-0}"
    AP_STA_TOTAL=$((AP_STA_TOTAL + sta))
    if grep -q "/$conf\b" <<<"$APPS"; then
      if [ "${en:-0}" -gt 0 ]; then AP_ENABLED_OK=$((AP_ENABLED_OK+1))
      else
        # process is up but the radio never logged AP-ENABLED: real bring-up
        # trouble - surface the error lines to help diagnose.
        problems+=("no AP-ENABLED in log (radio not up)")
        [ "${er:-0}" -gt 0 ] && problems+=("${er} error line(s) in log")
      fi
    fi
    if [ "${#problems[@]}" -eq 0 ]; then pass "$label [$wlan] ${essid:-hidden} ch${seen_chan:-?} $typ (${sta} sta)"
    else warn "$label [$wlan] (${sta} sta): ${problems[*]}" \
      "docker exec $APS_C cat /root/logs/hostapd_${logbase}.log   # + ns-ap: iw dev $wlan info"; fi
  done
  info "AP radios enabled: ${AP_ENABLED_OK}/${EXPECTED_AP_PROCS}; stations associated across all APs: ${AP_STA_TOTAL}"
  if [ "$AP_STA_TOTAL" -eq 0 ] && container_running "$CLI_C"; then
    warn "no stations associated to any AP - clients not connecting (check Clients container / re-run, clients rotate)" \
      "docker exec $CLI_C ip netns exec ns-client iw dev | grep -A5 Interface ; docker exec $CLI_C bash -lc 'tail -n +1 /root/logs/supplicant*.log | tail -80'"; fi

  if [ "$DO_DEEP_NET" = 1 ]; then
    for row in "${AP_ROWS[@]}"; do
      IFS='|' read -r label wlan ev cv mv ip typ conf <<<"$row"
      case "$typ" in MGT|PSK|OPN|OWE) : ;; *) continue ;; esac
      [ "$wlan" = wlan16 ] && continue
      if ns_ap "curl -fs -m 4 -o /dev/null http://$ip.1/login.php || curl -fs -m 4 -o /dev/null http://$ip.1/"; then
        pass "AP web up at $ip.1"
      else warn "AP web at $ip.1 did not answer" \
        "docker exec $APS_C ip netns exec ns-ap curl -v http://$ip.1/login.php ; docker exec $APS_C tail -20 /root/logs/apache2.log"; fi
    done
  fi

  ERRS="$(ns_ap 'grep -ilE "could not|failed to enable|cannot" /root/logs/hostapd_*.log 2>/dev/null | head')"
  [ -n "$ERRS" ] && warn "hostapd logs mention errors: $(tr '\n' ' ' <<<"$ERRS")" \
    "docker exec $APS_C grep -inE 'could not|failed to enable|cannot' $(tr '\n' ' ' <<<"$ERRS")"
else fail "AP container not running - skipping AP checks"; fi

########################################
# 4. Clients
########################################
section "Clients (ns-client)"
if container_running "$CLI_C"; then
  CLPS="$(ns_cli 'pgrep -a wpa_wifichallen 2>/dev/null')"
  n_cl="$(grep -c 'wpa_wifichallenge_supplicant' <<<"$CLPS")"; [ -z "$CLPS" ] && n_cl=0
  if [ "$n_cl" -ge "$EXPECTED_CLIENT_PROCS" ]; then pass "supplicant processes: $n_cl (expected >= $EXPECTED_CLIENT_PROCS)"
  else fail "supplicant processes: $n_cl (expected >= $EXPECTED_CLIENT_PROCS) - clients missing"; fi

  IWDEVC="$(ns_cli 'iw dev 2>/dev/null')"
  LINKDUMP="$(ns_cli 'for n in $(seq 40 58); do echo "@@wlan$n"; iw dev wlan$n link 2>/dev/null; ip -4 -o addr show wlan$n 2>/dev/null; done')"
  # Supplicant log health. There is no wpa_cli control socket (ctrl_interface is
  # disabled), so the log is the signal. MGT clients rotate on random timeouts,
  # so an instantaneous "iw link" often catches them mid-cycle - the log's
  # CTRL-EVENT-CONNECTED / EAP-SUCCESS proves the client DID authenticate. Logs
  # are on the container fs -> plain docker exec cat (append-mode for MGT).
  # c/e/x = lifetime CONNECTED / EAP-SUCCESS / auth-failure counts. ro/rf = the
  # same success/fail signals but only within the last 60 log lines, so we can
  # tell a healthily-rotating client (recent success) from one that connected in
  # the past but is now failing every attempt (regression, e.g. expired cert).
  CLI_LOGSTAT="$(dexec "$CLI_C" 'FAILP="CTRL-EVENT-EAP-FAILURE|4-Way Handshake failed|pre-shared key may be incorrect|CTRL-EVENT-(AUTH|ASSOC)-REJECT|Authentication request to the driver failed";
    for f in /root/logs/supplicant*.log; do [ -f "$f" ] || continue;
    b=$(basename "$f");
    c=$(grep -c "CTRL-EVENT-CONNECTED" "$f" 2>/dev/null);
    e=$(grep -c "CTRL-EVENT-EAP-SUCCESS" "$f" 2>/dev/null);
    x=$(grep -cE "$FAILP" "$f" 2>/dev/null);
    ro=$(tail -60 "$f" | grep -cE "CTRL-EVENT-CONNECTED|CTRL-EVENT-EAP-SUCCESS" 2>/dev/null);
    rf=$(tail -60 "$f" | grep -cE "$FAILP" 2>/dev/null);
    echo "$b c=${c:-0} e=${e:-0} x=${x:-0} ro=${ro:-0} rf=${rf:-0}"; done')"
  cli_field() { awk -v b="$1" -v k="$2" '$1==b{for(i=2;i<=NF;i++){split($i,a,"=");if(a[1]==k)print a[2]}}' <<<"$CLI_LOGSTAT"; }
  assoc_ok=0; assoc_exp=0; ever_connected=0
  for row in "${CLIENT_ROWS[@]}"; do
    IFS='|' read -r nn ev conf willassoc logf <<<"$row"
    wlan="wlan$nn"; essid="$(val "$ev")"
    problems=()
    grep -qw "$wlan" <<<"$IWDEVC" || { fail "client $wlan interface MISSING"; continue; }
    grep -q "/$conf\b" <<<"$CLPS" || problems+=("supplicant '$conf' down")
    # log-based history for this client
    lc="$(cli_field "$logf" c)"; le="$(cli_field "$logf" e)"; lx="$(cli_field "$logf" x)"
    lro="$(cli_field "$logf" ro)"; lrf="$(cli_field "$logf" rf)"
    connected_log=0; { [ "${lc:-0}" -gt 0 ] || [ "${le:-0}" -gt 0 ]; } && connected_log=1
    [ "$connected_log" = 1 ] && ever_connected=$((ever_connected+1))
    rotated=""   # non-empty => healthy-but-not-associated-right-now (still a PASS)
    if [ "$willassoc" = yes ]; then
      assoc_exp=$((assoc_exp+1))
      blk="$(awk -v w="@@$wlan" '$0==w{f=1;next} /^@@wlan/{f=0} f' <<<"$LINKDUMP")"
      cssid="$(awk -F': ' '/SSID:/{print $2; exit}' <<<"$blk")"
      if grep -q "Connected to" <<<"$blk"; then
        assoc_ok=$((assoc_ok+1))
        [ -n "$essid" ] && [ -n "$cssid" ] && [ "$cssid" != "$essid" ] && problems+=("assoc '$cssid'!='$essid'")
        grep -q "inet " <<<"$blk" || problems+=("no DHCP lease")
      elif [ "${lro:-0}" -gt 0 ]; then
        rotated="rotated, recently connected"                     # healthy rotation (e.g. MGT clients)
      elif [ "$connected_log" = 1 ] && [ "${lrf:-0}" -gt 0 ]; then
        problems+=("was connecting but recent attempts FAIL - regression? (${lrf} recent auth-fails; lifetime connects ${lc:-0}+${le:-0}; e.g. expired cert)")
      elif [ "$connected_log" = 1 ]; then
        rotated="connected earlier, idle now"                     # no recent activity either way
      else
        problems+=("never associated (no successful connect in log)")
        [ "${lrf:-0}" -gt 0 ] && problems+=("${lrf} recent auth-fail line(s)")
      fi
    fi
    # NB: clients 45/46 (PSK_NOAP), 51 (phishing) and 62 (randomized-MAC probe)
    # are *designed* not to associate, so auth failures / no connect in their logs
    # are expected - don't flag them.
    if [ "${#problems[@]}" -eq 0 ]; then
      tag=""; [ -n "$rotated" ] && tag=" ($rotated)" || { [ "$connected_log" = 1 ] && tag=" (connected)"; }
      pass "client $wlan ${essid:-probe-only} ok${tag}"
    else warn "client $wlan: ${problems[*]}" \
      "docker exec $CLI_C tail -40 /root/logs/$logf ; docker exec $CLI_C ip netns exec ns-client iw dev $wlan link"; fi
  done
  [ "$assoc_exp" -gt 0 ] && info "clients associated right now: $assoc_ok/$assoc_exp; clients that have EVER connected (from logs): $ever_connected/${#CLIENT_ROWS[@]} (MGT clients rotate; log count is the reliable one)"
  # EAP-TLS 1.3 regression detector (the wlan42 bug): wlan42 forces TLS 1.3, wlan58
  # forces TLS <=1.2, same AP + certs. If the 1.2 client authenticates but the 1.3
  # one never does, TLS 1.3 is broken server-side (hostapd built w/o CONFIG_TLSV13
  # or against GnuTLS/old OpenSSL) - exactly what shipped before the client rebuild.
  T13="$(dexec "$CLI_C" 'grep -c "CTRL-EVENT-EAP-SUCCESS" /root/logs/supplicantTLS.log 2>/dev/null')"; T13="${T13//[!0-9]/}"
  T12="$(dexec "$CLI_C" 'grep -c "CTRL-EVENT-EAP-SUCCESS" /root/logs/supplicantTLS_leak.log 2>/dev/null')"; T12="${T12//[!0-9]/}"
  if [ "${T13:-0}" -gt 0 ]; then pass "EAP-TLS over TLS 1.3 works (wlan42 authenticated; ${T13} successes)"
  elif [ "${T12:-0}" -gt 0 ]; then fail "EAP-TLS 1.3 BROKEN: TLS-1.2 client works (${T12}) but TLS-1.3 client (wlan42) never authenticates - hostapd/wpa_supplicant lacks CONFIG_TLSV13" \
    "docker exec $CLI_C grep -E 'unsupported protocol|EAP-FAILURE' /root/logs/supplicantTLS.log | tail"
  else info "EAP-TLS 1.3 check inconclusive (neither TLS client has authenticated yet; wifi-global AP up?)"; fi
  # Credential cross-check: every MGT client identity must exist server-side
  # (hostapd eap_user or freeradius users), else the server silently rejects it.
  # Reads the RUNTIME (already substituted) files on both sides.
  if container_running "$APS_C"; then
    CLI_IDS="$(dexec "$CLI_C" 'for f in /root/mgtClient/*.conf; do [ -f "$f" ] || continue; sed -nE "s/^[[:space:]]*identity=\"([^\"]+)\".*/\1/p" "$f"; done' | sort -u)"
    SRV_IDS="$(dexec "$APS_C" 'cat /root/mgt/*.eap_user /etc/freeradius/3.0/mods-config/files/users 2>/dev/null')"
    miss_ids=""
    while IFS= read -r id; do
      [ -z "$id" ] && continue
      grep -Fq "$id" <<<"$SRV_IDS" || miss_ids="$miss_ids [$id]"
    done <<<"$CLI_IDS"
    if [ -n "$SRV_IDS" ] && [ -z "$miss_ids" ]; then pass "all MGT client identities have a matching server credential"
    elif [ -n "$miss_ids" ]; then fail "MGT client identity with NO server-side entry (auth will always reject):$miss_ids" \
      "docker exec $CLI_C grep -rE 'identity=' /root/mgtClient/ ; docker exec $APS_C grep -rE '.' /root/mgt/*.eap_user"
    fi
  fi
  check "client apache up (client-side web service)" bash -c "docker exec $CLI_C ip netns exec ns-client curl -s -o /dev/null http://localhost"
else fail "Clients container not running - skipping client checks"; fi

########################################
# 5. nzyme WIDS + database
########################################
section "nzyme WIDS + database"
if container_running "$DB_C"; then
  check "postgres accepting connections" bash -c "docker exec $DB_C pg_isready -U nzyme"
  NT="$(docker exec "$DB_C" psql -U nzyme -d nzyme -tAc "select count(*) from information_schema.tables where table_schema='public'" 2>/dev/null)"
  NT="${NT//[!0-9]/}"
  if [ "${NT:-0}" -gt 0 ]; then pass "nzyme DB schema present ($NT tables)"; else warn "nzyme DB has no tables yet (schema not migrated)"; fi
else fail "nzyme-db container not running"; fi
if container_running "$NZYME_C"; then
  check "nzyme web up on :22900" bash -c "docker exec $NZYME_C curl -fs -o /dev/null http://localhost:22900"
  check "nzyme java process running" bash -c "docker exec $NZYME_C pgrep -f nzyme"
  # The nzyme image ships wireless-tools (iwconfig) but NOT `iw`, so probe wlan70
  # via sysfs (universal) and iwconfig - never `iw` inside this container. wlan70
  # is in the host netns (nzyme is network_mode:host), so the host's own `iw`
  # sees it too and is used as a fallback.
  if dexec "$NZYME_C" 'test -e /sys/class/net/wlan70' || { command -v iw >/dev/null 2>&1 && iw dev 2>/dev/null | grep -qw wlan70; }; then
    pass "nzyme tap radio wlan70 present"
    # monitor mode: sysfs type 803 == ARPHRD_IEEE80211_RADIOTAP, or iwconfig says Monitor
    if dexec "$NZYME_C" '[ "$(cat /sys/class/net/wlan70/type 2>/dev/null)" = 803 ] || iwconfig wlan70 2>/dev/null | grep -qi monitor' \
       || { command -v iw >/dev/null 2>&1 && iw dev wlan70 info 2>/dev/null | grep -qi "type monitor"; }; then
      pass "nzyme wlan70 in monitor mode (capturing)"
    else warn "nzyme wlan70 not in monitor mode - WIDS may not see traffic" \
      "docker exec $NZYME_C iwconfig wlan70 ; docker exec $NZYME_C cat /sys/class/net/wlan70/type"; fi
  else fail "nzyme tap radio wlan70 MISSING (not in /sys/class/net) - WIDS broken" \
    "docker exec $NZYME_C ls /sys/class/net/ ; iw dev | grep wlan70"; fi
  # nzyme log health: it writes /var/log/nzyme/nzyme.log (bind-mounted to host).
  if dexec "$NZYME_C" 'test -s /var/log/nzyme/nzyme.log'; then
    # Exclude the benign "Skipping unknown alert callback of type [file]" notice
    # (nzyme 1.2.2 doesn't know that config key; harmless).
    NZERR="$(dexec "$NZYME_C" 'grep -iE "ERROR|Exception|FATAL|Could not" /var/log/nzyme/nzyme.log 2>/dev/null | grep -cvE "Skipping unknown alert callback"')"; NZERR="${NZERR//[!0-9]/}"
    if [ "${NZERR:-0}" -eq 0 ]; then pass "nzyme.log clean (no non-benign ERROR/Exception)"
    else warn "nzyme.log has ${NZERR} ERROR/Exception line(s) - inspect ./nzyme/nzyme-logs/logs/nzyme.log" \
      "docker exec $NZYME_C grep -niE 'ERROR|Exception|FATAL|Could not' /var/log/nzyme/nzyme.log | grep -vE 'Skipping unknown alert callback' | tail -30"; fi
  else warn "nzyme.log empty/missing - nzyme may not have started logging" \
    "docker exec $NZYME_C ls -l /var/log/nzyme/ ; docker logs $NZYME_C | tail -40"; fi
else warn "nzyme container not running (WIDS detection needs it)"; fi

########################################
# 5b. Startup completion + container stdout logs
########################################
section "Startup completion + container logs"
# Both startAPs.sh and startClients.sh echo "ALL SET" as their last step, so its
# presence in the container's stdout proves the boot script ran to completion
# (not stuck mid-way). hostapd/ns-inet also print fatal errors to stdout only.
# Read the FULL logs (no --tail): the ns-inet markers are at the very start and
# "ALL SET" is mid-log, so tailing would miss them once hostapd stderr accrues.
# Container stdout is normally quiet after boot, so this stays cheap.
if container_running "$APS_C"; then
  APLOG="$(docker logs "$APS_C" 2>&1)"
  grep -q "ALL SET" <<<"$APLOG" && pass "AP startup completed (ALL SET marker present)" || warn "AP 'ALL SET' not seen - startAPs.sh may still be booting or stalled (opennds foreground blocks?)" "docker logs $APS_C | tail -60"
  grep -qiE "no uplink|WITHOUT internet sharing" <<<"$APLOG" && warn "AP ns-inet: no host uplink detected - APs running offline (internet challenges affected)"
  grep -qiE "modprobe: (FATAL|ERROR)|Module .* not found" <<<"$APLOG" && fail "AP container: mac80211_hwsim modprobe error in logs - radios won't come up"
  n_fatal="$(grep -ciE "Interface initialization failed|Could not (configure|set) channel|nl80211: Could not" <<<"$APLOG")"
  [ "${n_fatal:-0}" -gt 0 ] && warn "AP container stdout has ${n_fatal} hostapd bring-up error line(s) (stderr-only, not in per-AP logs)"
else info "AP container down - skipping AP log scan"; fi
if container_running "$CLI_C"; then
  CLLOG="$(docker logs "$CLI_C" 2>&1)"
  # NB: startClients.sh never prints "ALL SET" - its final `fping -l` (loop mode)
  # runs in the foreground and blocks the trailing echo. The supplicant-process
  # and per-client checks above already prove the clients came up, so here we
  # only scan container stdout for fatal namespace/module setup errors.
  if grep -qiE "modprobe: (FATAL|ERROR)|Cannot find device \"wlan" <<<"$CLLOG"; then
    warn "Client container stdout shows radio/module setup errors" \
      "docker logs $CLI_C 2>&1 | grep -iE 'modprobe|Cannot find device' | head"
  else pass "Client startup OK (supplicants up; no fatal setup errors in stdout)"; fi
else info "Clients container down - skipping client log scan"; fi

########################################
# 6. Optional over-the-air scan
########################################
if [ "$DO_SCAN" = 1 ]; then
  section "Over-the-air scan (attacker $SCAN_IFACE)"
  if command -v iw >/dev/null 2>&1 && iw dev 2>/dev/null | grep -qw "$SCAN_IFACE"; then
    info "scanning on $SCAN_IFACE ..."
    SCAN="$(iw dev "$SCAN_IFACE" scan 2>/dev/null)"
    for row in "${AP_ROWS[@]}"; do
      IFS='|' read -r label wlan ev cv mv ip typ conf <<<"$row"
      [ "$typ" = OPNHID ] && continue
      essid="$(val "$ev")"; [ -z "$essid" ] && continue
      if grep -qiF "SSID: $essid" <<<"$SCAN"; then pass "OTA beacon: $essid"
      else warn "OTA beacon not seen: $essid (channel-hop timing, retry)"; fi
    done
  else warn "attacker radio $SCAN_IFACE unavailable on host - skipping OTA scan (set SCAN_IFACE=)"; fi
fi

########################################
# 7. Attacker toolkit
########################################
if [ "$DO_TOOLS" = 1 ]; then
  section "Attacker toolkit ($TOOL_CTX)"
  if [ "$TOOL_CTX" = host ] && ! command -v aircrack-ng >/dev/null 2>&1; then
    warn "no attacker container and no tools on host - start Attacker container or run in the lab VM"
  fi
  for row in "${TOOLS[@]}"; do
    IFS='|' read -r label cmd <<<"$row"
    if tool_run "$cmd"; then pass "tool: $label"; else warn "tool missing: $label"; fi
  done
  if [ "$TOOL_CTX" = attacker ]; then
    docker exec "$ATT_C" iw dev 2>/dev/null | grep -qw wlan0 && pass "attacker radio wlan0 present" || warn "attacker radio wlan0 not visible"
    docker exec "$ATT_C" bash -lc 'iw phy 2>/dev/null | grep -q monitor' && pass "monitor mode supported" || warn "monitor mode not reported by iw phy"
  fi
fi

########################################
# 7b. Client-less PMKID target (campus AP)
########################################
# The wifi-campus/wifi-university AP is a client-less PMKID target that
# needs TWO patches (see APs/PMKID_TESTING.md): the mac80211_hwsim ACK patch (so
# the AP's EAPOL msg1 reaches hcxdumptool under hwsim) and the hostapd 2.10 PMKID
# patch (so msg1 carries the PMKID KDE for WPA2-PSK). hcxdumptool must also be new
# enough for -w/--rds (the distro 6.2.6 build lacks both).
section "Client-less PMKID target (campus AP)"
# (a) hwsim ACK patch: the LOADED module must be the WiFiChallenge build. The patch
# stamps MODULE_VERSION("...-WiFiChallengeLab-version"); stock hwsim has none.
HWVER=""; container_running "$APS_C" && HWVER="$(dexec "$APS_C" 'cat /sys/module/mac80211_hwsim*/version 2>/dev/null | head -1')"
if grep -qi 'WiFiChallengeLab' <<<"$HWVER"; then
  pass "hwsim ACK patch loaded (mac80211_hwsim version: $HWVER)"
elif container_running "$APS_C"; then
  fail "mac80211_hwsim is not the patched WiFiChallenge build (version: '${HWVER:-none}') - client-less PMKID msg1 won't be ACKed" \
    "docker exec $APS_C cat /sys/module/mac80211_hwsim*/version   # rebuild: cd /root/mac80211_hwsim_WiFiChallenge && bash install.sh"
else
  info "AP container down - skipping hwsim ACK-patch check"
fi
# (b) hcxdumptool new enough for -w/--rds (this is what broke on the distro 6.2.6).
HCXV=""
if [ "$TOOL_CTX" = attacker ]; then HCXV="$(docker exec "$ATT_C" bash -lc 'hcxdumptool --version 2>/dev/null' | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
elif command -v hcxdumptool >/dev/null 2>&1; then HCXV="$(hcxdumptool --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"; fi
if [ -n "$HCXV" ]; then
  IFS=. read -r hmaj hmin _ <<<"$HCXV"
  if [ "${hmaj:-0}" -gt 6 ] || { [ "${hmaj:-0}" -eq 6 ] && [ "${hmin:-0}" -ge 3 ]; }; then
    pass "hcxdumptool $HCXV supports -w/--rds (client-less PMKID)"
  else warn "hcxdumptool $HCXV predates -w/--rds (need >= 6.3; distro 6.2.6 lacks them) - rebuild from ZerBea source" \
    "docker exec $ATT_C hcxdumptool --version"; fi
else warn "hcxdumptool not found to version-check (client-less PMKID capture unavailable)"; fi
# (c) Optional live end-to-end capture - proves BOTH patches at once. Gated behind
# --scan (it actively associates/injects). Channel + BSSID come from the loaded
# wlan_config, so this follows any channel/BSSID change automatically.
if [ "$DO_SCAN" = 1 ] && [ "$TOOL_CTX" = attacker ] && [ "$HAVE_CONF" = 1 ]; then
  pm_bssid="$(val MAC_ROAM1)"; pm_ch="$(val CHANNEL_ROAM1)"; pm_nc="$(tr -d ':' <<<"${pm_bssid,,}")"
  if [ -n "$pm_bssid" ] && [ -n "$pm_ch" ] && docker exec "$ATT_C" iw dev 2>/dev/null | grep -qw "$SCAN_IFACE"; then
    info "live PMKID capture on $SCAN_IFACE ch ${pm_ch}a bssid $pm_bssid (~22s) ..."
    GOTP="$(docker exec "$ATT_C" bash -lc '
      rm -f /tmp/pmkidtest.* 2>/dev/null
      hcxdumptool --bpfc="wlan addr3 '"$pm_nc"'" > /tmp/pmkidtest.bpf 2>/dev/null
      timeout 22 hcxdumptool -i '"$SCAN_IFACE"' -c '"$pm_ch"'a -w /tmp/pmkidtest.pcapng --bpf=/tmp/pmkidtest.bpf >/dev/null 2>&1
      hcxpcapngtool -o /tmp/pmkidtest.22000 /tmp/pmkidtest.pcapng* >/dev/null 2>&1
      grep -c "^WPA\*01\*" /tmp/pmkidtest.22000 2>/dev/null')"
    GOTP="${GOTP//[!0-9]/}"
    if [ "${GOTP:-0}" -gt 0 ]; then pass "live client-less PMKID captured (WPA*01* x${GOTP}) - hwsim ACK + hostapd PMKID patches both working"
    else fail "live capture produced NO PMKID (roam1 $pm_bssid ch $pm_ch) - hostapd PMKID patch missing or roam1 AP down" \
      "docker exec $ATT_C bash -lc 'hcxdumptool -i $SCAN_IFACE -c ${pm_ch}a -w /tmp/p.pcapng --rds=1'   # watch the P column; see APs/PMKID_TESTING.md"; fi
  else warn "live PMKID capture skipped (need roam1 MAC+channel in wlan_config and $SCAN_IFACE on attacker)"; fi
elif [ "$DO_SCAN" = 0 ]; then
  info "live PMKID capture skipped (add --scan to run the end-to-end capture that also proves the hostapd PMKID patch)"
fi
fi  # end !ONLY_CHALLENGES

########################################
# 8. Challenge readiness matrix (0..30)
########################################
# Printed ONLY when explicitly requested with --challenges. A normal run never
# emits it, so a shared test log/screenshot can't expose the challenge inventory.
# Even here it reports only infra readiness per challenge - never the objective or
# the technique to solve it. Each row is "num |network |dependency".
if [ "$ONLY_CHALLENGES" = 1 ]; then
section "Challenge readiness matrix (0..30)"
printf "  ${BOLD}%-3s %-24s %s${N}\n" "#" "Network" "Status"
CHALLENGES=(
  "0 |(VM local)             |vm"
  "1 |wifi-global            |ap:wlan18"
  "2 |wifi-IT                |cli"
  "3 |(probe client)         |cli"
  "4 |wifi-free              |ap:wlan26"
  "5 |wifi-free              |ap:wlan26"
  "6 |wifi-guest             |apn:wlan10"
  "7 |wifi-old               |ap:wlan11"
  "8 |wifi-mobile            |ap:wlan12"
  "9 |wifi-mobile            |ap:wlan12"
  "10|wifi-mobile            |ap:wlan12"
  "11|wifi-mobile            |cli"
  "12|wifi-offices           |cli"
  "13|wifi-management        |ap:wlan24"
  "14|wifi-IT                |ap:wlan25"
  "15|wifi-regional          |mgt:wlan17"
  "16|wifi-corp              |mgt:wlan15"
  "17|wifi-global            |mgt:wlan18"
  "18|wifi-corp              |mgt:wlan15"
  "19|wifi-corp              |mgt:wlan15"
  "20|wifi-corp              |mgt:wlan15"
  "21|wifi-regional-tablets  |mgt:wlan28"
  "22|wifi-regional          |mgt:wlan17"
  "23|wifi-global            |mgt:wlan18"
  "24|wifi-regional          |mgt:wlan17"
  "25|wifi-corp              |mgt:wlan15"
  "26|wifi-global            |mgt:wlan18"
  "27|(nzyme)                |nzyme"
  "28|wifi-event             |ap:wlan13"
  "29|wifi-corp-legacy       |mgt:wlan27"
  "30|wifi-gratis            |ap:wlan30"
)
IWDEV_M=""; container_running "$APS_C" && IWDEV_M="$(ns_ap 'iw dev 2>/dev/null')"
CLI_UP=0;   container_running "$CLI_C" && CLI_UP=1
NZ_UP=0;    container_running "$NZYME_C" && container_running "$DB_C" && NZ_UP=1
# In --challenges-only mode the AP section (which sets these) was skipped, so probe
# freeradius/dnsmasq here to keep the readiness accurate instead of false-"partial".
if container_running "$APS_C"; then
  [ "$FREERADIUS_OK" = 0 ] && ns_ap 'pgrep -x freeradius >/dev/null' && FREERADIUS_OK=1
  [ "$DNSMASQ_OK" = 0 ]    && ns_ap 'pgrep -x dnsmasq >/dev/null'    && DNSMASQ_OK=1
fi
ap_up(){ grep -qw "$1" <<<"$IWDEV_M"; }
for row in "${CHALLENGES[@]}"; do
  IFS='|' read -r num net dep <<<"$row"
  num="$(echo "$num"|xargs)"; net="$(echo "$net"|xargs)"; dep="$(echo "$dep"|xargs)"
  dt="${dep%%:*}"; da="${dep##*:}"; st="${G}ready${N}"; note=""
  case "$dt" in
    ap)  ap_up "$da" && st="${G}ready${N}" || { st="${R}NOT READY${N}"; note="($da down)"; } ;;
    apn) if ap_up "$da"; then [ "$DNSMASQ_OK" = 1 ] && st="${G}ready${N}" || { st="${Y}partial${N}"; note="(captive DHCP?)"; }; else st="${R}NOT READY${N}"; note="($da down)"; fi ;;
    mgt) # Only the wlan27 AP uses freeradius; every other MGT AP runs hostapd's
         # embedded EAP server, so it's ready as soon as the AP is up.
         if ap_up "$da"; then
           if [ "$da" = wlan27 ] && [ "$FREERADIUS_OK" != 1 ]; then st="${Y}partial${N}"; note="(freeradius down)"; else st="${G}ready${N}"; fi
         else st="${R}NOT READY${N}"; note="($da down)"; fi ;;
    cli) [ "$CLI_UP" = 1 ] && st="${G}ready${N}" || { st="${R}NOT READY${N}"; note="(clients down)"; } ;;
    nzyme) [ "$NZ_UP" = 1 ] && st="${G}ready${N}" || { st="${Y}check${N}"; note="(nzyme/db down)"; } ;;
    vm)  st="${C}manual${N}"; note="(VM file)" ;;
  esac
  printf "  %-3s %-24s %b %s\n" "$num" "$net" "$st" "$note"
done
fi  # end challenge matrix (only with --challenges)

########################################
# Summary
########################################
section "Summary"
printf "  ${G}PASS: %d${N}   ${Y}WARN: %d${N}   ${R}FAIL: %d${N}\n" "$PASS" "$WARN" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
  printf "\n  ${R}Failures:${N}\n"; for f in "${FAILED_ITEMS[@]}"; do printf "   - %s\n" "$f"; done; echo; exit 1
fi
printf "\n  ${G}Lab looks healthy.${N}\n\n"; exit 0
