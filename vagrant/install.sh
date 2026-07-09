#!/bin/bash
#set -euo pipefail

DEV=${1:-false}
LOCATION=${2:-remote}

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes
export DEBIAN_PRIORITY=critical
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFNEW=1
export APT_LISTCHANGES_FRONTEND=none

# Fix for Debian 12 python packaging guardrails when scripts use "pip install" globally
# Best practice is venv or pipx, but this prevents "externally-managed-environment" hard failures.
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_DISABLE_PIP_VERSION_CHECK=1

DEB_CODENAME="bookworm"

date

# ---------- helpers -----------------------------------------------------------
run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

preseed_desktop_debconf() {
  run_as_root debconf-set-selections <<'EOF'
keyboard-configuration keyboard-configuration/modelcode string pc105
keyboard-configuration keyboard-configuration/layoutcode string us
keyboard-configuration keyboard-configuration/variantcode string
keyboard-configuration keyboard-configuration/optionscode string
keyboard-configuration keyboard-configuration/store_defaults_in_debconf_db boolean true
keyboard-configuration keyboard-configuration/compose select No compose key
keyboard-configuration keyboard-configuration/toggle select No toggling
keyboard-configuration keyboard-configuration/xkb-keymap select us
console-setup console-setup/charmap47 select UTF-8
console-setup console-setup/codeset47 select Guess optimal character set
console-setup console-setup/fontface47 select Fixed
console-setup console-setup/fontsize-text47 select 16
EOF
}

apt_update() {
  run_as_root env \
    DEBIAN_FRONTEND="$DEBIAN_FRONTEND" \
    DEBCONF_NONINTERACTIVE_SEEN="$DEBCONF_NONINTERACTIVE_SEEN" \
    DEBCONF_NOWARNINGS="$DEBCONF_NOWARNINGS" \
    DEBIAN_PRIORITY="$DEBIAN_PRIORITY" \
    NEEDRESTART_MODE="$NEEDRESTART_MODE" \
    UCF_FORCE_CONFFNEW="$UCF_FORCE_CONFFNEW" \
    APT_LISTCHANGES_FRONTEND="$APT_LISTCHANGES_FRONTEND" \
    apt-get -o Dpkg::Use-Pty=0 update -y </dev/null
}

apt_install() {
  run_as_root env \
    DEBIAN_FRONTEND="$DEBIAN_FRONTEND" \
    DEBCONF_NONINTERACTIVE_SEEN="$DEBCONF_NONINTERACTIVE_SEEN" \
    DEBCONF_NOWARNINGS="$DEBCONF_NOWARNINGS" \
    DEBIAN_PRIORITY="$DEBIAN_PRIORITY" \
    NEEDRESTART_MODE="$NEEDRESTART_MODE" \
    UCF_FORCE_CONFFNEW="$UCF_FORCE_CONFFNEW" \
    APT_LISTCHANGES_FRONTEND="$APT_LISTCHANGES_FRONTEND" \
    apt-get -o Dpkg::Use-Pty=0 install -y \
      -o Dpkg::Options::="--force-confdef" \
      -o Dpkg::Options::="--force-confnew" \
      "$@" </dev/null
}

apt_remove() {
  run_as_root env \
    DEBIAN_FRONTEND="$DEBIAN_FRONTEND" \
    DEBCONF_NONINTERACTIVE_SEEN="$DEBCONF_NONINTERACTIVE_SEEN" \
    DEBCONF_NOWARNINGS="$DEBCONF_NOWARNINGS" \
    DEBIAN_PRIORITY="$DEBIAN_PRIORITY" \
    NEEDRESTART_MODE="$NEEDRESTART_MODE" \
    UCF_FORCE_CONFFNEW="$UCF_FORCE_CONFFNEW" \
    APT_LISTCHANGES_FRONTEND="$APT_LISTCHANGES_FRONTEND" \
    apt-get -o Dpkg::Use-Pty=0 remove -y "$@" </dev/null || true
}

apt_purge() {
  run_as_root env \
    DEBIAN_FRONTEND="$DEBIAN_FRONTEND" \
    DEBCONF_NONINTERACTIVE_SEEN="$DEBCONF_NONINTERACTIVE_SEEN" \
    DEBCONF_NOWARNINGS="$DEBCONF_NOWARNINGS" \
    DEBIAN_PRIORITY="$DEBIAN_PRIORITY" \
    NEEDRESTART_MODE="$NEEDRESTART_MODE" \
    UCF_FORCE_CONFFNEW="$UCF_FORCE_CONFFNEW" \
    APT_LISTCHANGES_FRONTEND="$APT_LISTCHANGES_FRONTEND" \
    apt-get -o Dpkg::Use-Pty=0 purge -y "$@" </dev/null || true
}

service_exists() {
  systemctl list-unit-files "$1" >/dev/null 2>&1
}

require_pkg() {
  if ! dpkg -s "$1" >/dev/null 2>&1; then
    apt_install "$@"
  fi
}

# ---------- IMPORTANT: unmask PackageKit if a base image masked it ------------
# Prevents: "Unit packagekit.service is masked" during GNOME and various installers
sudo systemctl unmask packagekit.service packagekit.socket 2>/dev/null || true
sudo systemctl enable --now packagekit.service 2>/dev/null || true

# ---------- initramfs MODULES tweak (qemu) -----------------------------------
CONF="/etc/initramfs-tools/initramfs.conf"
if [ -f "$CONF" ]; then
  if grep -q '^MODULES=dep' "$CONF"; then
    sudo sed -i 's/^MODULES=dep/MODULES=most/' "$CONF"
    sudo update-initramfs -u -k all
    echo "Initramfs rebuilt with MODULES=most"
  fi
fi

# ---------- base system -------------------------------------------------------
apt_update

# Ubuntu-only package, remove any attempts to install it (kept here as documentation)
# update-manager-core does not exist on Debian

# optional housekeeping
apt_purge unattended-upgrades

# Timezone
sudo timedatectl set-timezone Europe/Madrid

# ---------- disable Debian automatic updates ---------------------------------
# Stop, disable and mask every periodic apt unit so the lab never auto-updates
# (avoids apt locks and surprise package changes mid-challenge).
for unit in apt-daily.timer apt-daily-upgrade.timer apt-daily.service apt-daily-upgrade.service; do
  sudo systemctl stop "$unit" 2>/dev/null || true
  sudo systemctl disable "$unit" 2>/dev/null || true
  sudo systemctl mask "$unit" 2>/dev/null || true
done
# Turn off the APT periodic config itself (effective even without unattended-upgrades).
sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null <<'EOF'
APT::Periodic::Update-Package-Lists "0";
APT::Periodic::Download-Upgradeable-Packages "0";
APT::Periodic::Unattended-Upgrade "0";
APT::Periodic::AutocleanInterval "0";
EOF

# Remove fwupd if present
apt_remove fwupd

# Only disable NM wait-online if it exists
if service_exists NetworkManager-wait-online.service; then
  sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null || true
fi

# ---------- boot tweaks -------------------------------------------------------
bak="/etc/default/grub.$(date +%F_%H%M%S).bak"
sudo cp /etc/default/grub "$bak"

if grep -qi "VirtualBox" /sys/class/dmi/id/product_name 2>/dev/null; then
  IPV6_FLAG="ipv6.disable=1"
else
  IPV6_FLAG=""
fi

sudo tee /etc/default/grub >/dev/null <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR=\$(lsb_release -i -s 2> /dev/null || echo Debian)
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash net.ifnames=0 biosdevname=0 no_timer_check clocksource=tsc $IPV6_FLAG"
GRUB_CMDLINE_LINUX=""
EOF

sudo update-grub
sudo update-initramfs -u
apt_update

# may not exist
sudo systemctl disable bettercap 2>/dev/null || true

# ---------- user --------------------------------------------------------------
if ! id -u user >/dev/null 2>&1; then
  sudo useradd -m -s /bin/bash user
  echo "user:user" | sudo chpasswd
fi
sudo usermod -aG sudo user
echo "user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/zzz-user >/dev/null
sudo chmod 0440 /etc/sudoers.d/zzz-user

sudo touch /home/user/.Xauthority
sudo chmod 600 /home/user/.Xauthority
sudo chown user:user /home/user/.Xauthority

# ---------- polkit tweaks -----------------------------------------------------
sudo tee /etc/polkit-1/localauthority/50-local.d/47-allow-wifi-scan.pkla >/dev/null <<'EOF'
[Allow Wifi Scan]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.wifi.scan;org.freedesktop.NetworkManager.enable-disable-wifi;org.freedesktop.NetworkManager.settings.modify.own;org.freedesktop.NetworkManager.settings.modify.system;org.freedesktop.NetworkManager.network-control
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla >/dev/null <<'EOF'
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# ---------- Python sanity for Debian 12 --------------------------------------
# Fixes:
# - python2-dev missing
# - update-alternatives for python2 failing
# - pipenv "Python 2" flags failing
# Prefer Python 3 everywhere and provide "python" alias.
apt_install python3 python3-dev python3-venv python3-pip python-is-python3 pipx
sudo -u user pipx ensurepath 2>/dev/null || true

# ---------- Docker for Debian 12 ---------------------------------------------
require_pkg apt-transport-https ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${DEB_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

apt_update
apt_install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
require_pkg bridge-utils
sudo systemctl enable --now docker

# ---------- Tools that previously failed to build on Bookworm ----------------
# Fix for hcxtools build errors like SIOCGSTAMP undeclared:
# install the distro package instead of compiling an older source snapshot.
apt_install hcxtools

# ---------- Cron in case update kernel ---------------------------------------
cat >/usr/local/sbin/wifi_install.sh <<'EOF'
#!/bin/bash
sleep 60
cd /var/WiFiChallengeLab-docker/APs/mac80211_hwsim || exit 1
bash install.sh
sleep 120
cd /var/WiFiChallengeLab-docker/APs/mac80211_hwsim || exit 1
bash install.sh
EOF
chmod +x /usr/local/sbin/wifi_install.sh

echo '@reboot root /usr/local/sbin/wifi_install.sh >>/var/log/wifi_install.log 2>&1' \
  >/etc/cron.d/wifi_install
chmod 644 /etc/cron.d/wifi_install

# ---------- WiFiChallengeLab --------------------------------------------------
cd /var
if [ "$DEV" = "true" ]; then
  git clone -b dev https://github.com/r4ulcl/WiFiChallengeLab-docker || true
else
  git clone https://github.com/r4ulcl/WiFiChallengeLab-docker || true
fi

cd /var/WiFiChallengeLab-docker

cd /var/WiFiChallengeLab-docker/nzyme/nzyme-logs/
rm -rf logs/ data/
require_pkg p7zip-full
7z x nzyme-logs.7z

cd /var/WiFiChallengeLab-docker/APs/mac80211_hwsim/
sudo bash install.sh

cd /var/WiFiChallengeLab-docker
if [ "$LOCATION" = "local" ]; then
  sudo docker compose -f docker-compose-local.yml build
  docker tag wifichallengelab-docker-clients r4ulcl/wifichallengelab-clients || true
  docker tag wifichallengelab-docker-aps r4ulcl/wifichallengelab-aps || true
  docker tag wifichallengelab-docker-nzyme r4ulcl/wifichallengelab-nzyme || true
  docker image rm wifichallengelab-docker-nzyme wifichallengelab-docker-aps wifichallengelab-docker-clients || true
fi

if [ "$DEV" = "true" ]; then
  sudo docker compose -f docker-compose-dev.yml up -d
else
  sudo docker compose -f docker-compose.yml up -d
fi

# ---------- flags and helper scripts -----------------------------------------
echo 'flag{2162ae75cdefc5f731dfed4efa8b92743d1fb556}' | sudo tee /root/flag.txt

sudo tee /root/restartWiFi.sh /home/user/restartWiFi.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo modprobe mac80211_hwsim_WiFiChallenge -r
sudo docker compose restart aps
sudo docker compose restart clients
EOF
sudo chmod +x /root/restartWiFi.sh /home/user/restartWiFi.sh
sudo chown user:user /home/user/restartWiFi.sh

sudo tee /root/resetWiFi.sh /home/user/resetWiFi.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
docker compose down
docker compose up -d
EOF
sudo chmod +x /root/resetWiFi.sh /home/user/resetWiFi.sh
sudo chown user:user /home/user/resetWiFi.sh


sudo tee /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo docker compose pull
sudo docker compose up --detach
EOF
sudo chmod +x /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh
sudo chown user:user /home/user/updateWiFiChallengeLab.sh

# ---------- Nzyme start/stop helper scripts ----------------------------------
# Start the Nzyme WIDS and its PostgreSQL database (both detached/in background)
sudo tee /root/startNzyme.sh /home/user/startNzyme.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker || exit 1
nohup sudo docker compose up -d db nzyme >/tmp/startNzyme.log 2>&1 &
notify-send -i /opt/background/nzyme.ico "Nzyme" "Starting Nzyme and database in the background..." 2>/dev/null || true
EOF
sudo chmod +x /root/startNzyme.sh /home/user/startNzyme.sh
sudo chown user:user /home/user/startNzyme.sh

# Stop the Nzyme WIDS and its PostgreSQL database (in the background)
sudo tee /root/stopNzyme.sh /home/user/stopNzyme.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker || exit 1
nohup sudo docker compose stop nzyme db >/tmp/stopNzyme.log 2>&1 &
notify-send -i /opt/background/nzyme.ico "Nzyme" "Stopping Nzyme and database in the background..." 2>/dev/null || true
EOF
sudo chmod +x /root/stopNzyme.sh /home/user/stopNzyme.sh
sudo chown user:user /home/user/stopNzyme.sh

# Desktop launchers so the user can double-click to start/stop Nzyme
sudo mkdir -p /home/user/Desktop

sudo tee /home/user/Desktop/StartNzyme.desktop >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Start Nzyme
Comment=Start the Nzyme WIDS and its database in the background
Exec=/home/user/startNzyme.sh
Icon=/opt/background/nzyme.ico
Terminal=false
Categories=Utility;
EOF

sudo tee /home/user/Desktop/StopNzyme.desktop >/dev/null <<'EOF'
[Desktop Entry]
Type=Application
Version=1.0
Name=Stop Nzyme
Comment=Stop the Nzyme WIDS and its database in the background
Exec=/home/user/stopNzyme.sh
Icon=/opt/background/nzyme.ico
Terminal=false
Categories=Utility;
EOF

sudo chmod +x /home/user/Desktop/StartNzyme.desktop /home/user/Desktop/StopNzyme.desktop
sudo chown -R user:user /home/user/Desktop

# ---------- Wi-Fi scan powersave tweak ---------------------------------------
sudo sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf 2>/dev/null || true
if service_exists NetworkManager.service; then
  sudo systemctl restart NetworkManager || true
fi

# ---------- misc assets -------------------------------------------------------
sudo mkdir -p /opt/background/
sudo cp /var/WiFiChallengeLab-docker/WiFiChallengeLab.png /opt/background/ || true

require_pkg jq dunst libnotify-bin dbus-user-session wget curl
sudo mkdir -p /opt/background
sudo curl -fsSL -o /opt/background/nzyme.ico https://www.nzyme.org/assets/img/favicon.png || true
sudo chown -R user:user /opt/background/

# nzyme notification loop
sudo tee /var/nzyme-alerts.sh >/dev/null <<'EOF'
#!/bin/bash
PID_FILE=/var/run/nzyme-alerts.pid
if [ -e "$PID_FILE" ] && ps -p "$(cat "$PID_FILE")" >/dev/null 2>&1; then
  exit 0
fi
trap "rm -f $PID_FILE; exit" SIGINT SIGTERM
echo $$ >"$PID_FILE"

URL="http://localhost:22900/assets/static/favicon-32x32.png"
DEST="/opt/background/nzyme.ico"
if [ "$(curl -s -o /dev/null -w "%{http_code}" "$URL")" = "200" ]; then
  curl -fsSL -o "$DEST" "$URL" || true
fi

LOG="/var/WiFiChallengeLab-docker/nzyme/nzyme-logs/logs/alerts.log"
GREP="MULTIPLE_SIGNAL_TRACKS|BANDIT_CONTACT|DEAUTH_FLOOD|UNEXPECTED_FINGERPRINT|UNEXPECTED_BSSID|UNEXPECTED_CHANNEL"

LAST=$(grep -E "$GREP" "$LOG" 2>/dev/null | tail -n1 | jq -r .message 2>/dev/null || echo "")
while true; do
  NOW=$(grep -E "$GREP" "$LOG" 2>/dev/null | tail -n1 | jq -r .message 2>/dev/null || echo "")
  if [ -n "$NOW" ] && [ "$NOW" != "$LAST" ]; then
    LAST="$NOW"
    notify-send -i /opt/background/nzyme.ico "WIDS Nzyme v1" "$NOW" || true
  fi
  sleep 1
done
EOF
sudo chown user:user /var/nzyme-alerts.sh
sudo chmod +x /var/nzyme-alerts.sh

echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-user.log 2>&1 &' >> /home/user/.bashrc
if id -u vagrant >/dev/null 2>&1; then
  echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-vagrant.log 2>&1 &' >> /home/vagrant/.bashrc
fi

# ---------- monitor mode helper ----------------------------------------------
sudo tee /var/aux.sh >/dev/null <<'EOF'
#!/bin/bash
sudo ip link set wlan70 down || exit 0
sudo iw wlan70 set type monitor || exit 0
sudo ip link set wlan70 up || exit 0
EOF
sudo chmod +x /var/aux.sh

# ---------- Install GNOME -----------------------------------------------------
preseed_desktop_debconf
apt_update
apt_install gnome-core gnome-shell gnome-terminal nautilus gnome-control-center gnome-system-monitor \
  gnome-tweaks gnome-shell-extension-dashtodock gnome-shell-extension-prefs gnome-remote-desktop \
  gdm3 network-manager-gnome gnome-calculator evince eog file-roller gnome-shell-extension-desktop-icons-ng

sudo systemctl enable gdm3 || true
sudo systemctl set-default graphical.target || true

apt_install htop xpra tmux

# Install RDP
echo 'Install RDP server'
sudo bash vagrant/installRDP.sh user

# ---------- first login desktop setup ----------------------------------------
sudo tee /etc/configureUser.sh >/dev/null <<'EOF'
#!/bin/bash
set -e

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes
export DEBIAN_PRIORITY=critical
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFNEW=1
export APT_LISTCHANGES_FRONTEND=none

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval "$(dbus-launch --sh-syntax)"
fi

sudo env \
  DEBIAN_FRONTEND="$DEBIAN_FRONTEND" \
  DEBCONF_NONINTERACTIVE_SEEN="$DEBCONF_NONINTERACTIVE_SEEN" \
  DEBCONF_NOWARNINGS="$DEBCONF_NOWARNINGS" \
  DEBIAN_PRIORITY="$DEBIAN_PRIORITY" \
  NEEDRESTART_MODE="$NEEDRESTART_MODE" \
  UCF_FORCE_CONFFNEW="$UCF_FORCE_CONFFNEW" \
  APT_LISTCHANGES_FRONTEND="$APT_LISTCHANGES_FRONTEND" \
  apt-get -o Dpkg::Use-Pty=0 install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confnew" \
    gnome-shell-extension-dashtodock gnome-tweaks dconf-cli locales firefox-esr \
    </dev/null >/dev/null || true

sudo mkdir -p /opt/background
sudo cp /var/WiFiChallengeLab-docker/WiFiChallengeLab.png /opt/background/ 2>/dev/null || true
gsettings set org.gnome.desktop.background picture-uri "file:///opt/background/WiFiChallengeLab.png" || true
gsettings set org.gnome.desktop.background picture-uri-dark "file:///opt/background/WiFiChallengeLab.png" || true

gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark' || true
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita' || true

gsettings set org.gnome.desktop.session idle-delay 0 || true
gsettings set org.gnome.desktop.screensaver lock-enabled false || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' || true
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' || true

# Stop GNOME Software from downloading or offering automatic updates.
gsettings set org.gnome.software download-updates false 2>/dev/null || true
gsettings set org.gnome.software download-updates-notify false 2>/dev/null || true
gsettings set org.gnome.software allow-updates false 2>/dev/null || true

gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT' || true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide false || true
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true || true
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48 || true

if command -v gnome-extensions >/dev/null 2>&1; then
  gnome-extensions enable dash-to-dock@micxgx.gmail.com 2>/dev/null || true
fi

gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' || true
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close' || true

sudo sed -i '/^# *es_ES.UTF-8/s/^# *//' /etc/locale.gen || true
sudo locale-gen || true

gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'es')]" || true
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:win_space_toggle']" || true

gsettings set org.gnome.shell favorite-apps "[
  'org.gnome.Terminal.desktop',
  'firefox-esr.desktop',
  'org.wireshark.Wireshark.desktop',
  'org.gnome.Nautilus.desktop',
  'gnome-control-center.desktop'
]" || true

# The WiFiChallenge CA is trusted system-wide and in Firefox during
# provisioning (see the CA/policies.json section in install.sh), so no per-login
# certutil dance is needed here. Re-assert the system trust store in case this
# profile predates that step; Firefox picks up the CA from its enterprise policy
# on first launch.
if [ -f /var/WiFiChallengeLab-docker/certs/ca.crt ] \
   && [ ! -f /usr/local/share/ca-certificates/WiFiChallenge-CA.crt ]; then
  sudo install -m 0644 /var/WiFiChallengeLab-docker/certs/ca.crt \
    /usr/local/share/ca-certificates/WiFiChallenge-CA.crt 2>/dev/null || true
  sudo update-ca-certificates || true
fi

# Auto-run alerts script
if ! grep -q "nzyme-alerts" ~/.bashrc 2>/dev/null; then
  echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-user.log 2>&1 &' >> ~/.bashrc
fi

# Additional GNOME tweaks
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED' || true
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.6 || true
gsettings set org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true || true
gsettings set org.gnome.shell.extensions.dash-to-dock unity-backlit-items true || true
gsettings set org.gnome.desktop.wm.preferences audible-bell false || true
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true

# Desktop icons (DING) enable + allow creating files/folders on desktop
# Enable DING extension if present
gnome-extensions list 2>/dev/null | grep -qx 'ding@rastersoft.com' && \
  gnome-extensions enable ding@rastersoft.com || true

# Make sure Nautilus is NOT managing the desktop (DING does)
gsettings set org.gnome.desktop.background show-desktop-icons false || true

# Optional: ensure file manager can handle desktop related actions
gsettings set org.gnome.nautilus.preferences show-delete-permanently true || true

# Allow launching .desktop / scripts on double-click and trust our Nzyme launchers
gsettings set org.gnome.nautilus.preferences executable-text-activation 'launch' || true
gsettings set org.gnome.shell.extensions.ding show-link-emblem false 2>/dev/null || true
for launcher in "$HOME"/Desktop/StartNzyme.desktop "$HOME"/Desktop/StopNzyme.desktop; do
  if [ -f "$launcher" ]; then
    chmod +x "$launcher" || true
    gio set "$launcher" metadata::trusted true 2>/dev/null || true
  fi
done

# Ensure user has sudo
sudo usermod -aG sudo user || true

# Clean up triggers for first login
sudo rm -f /var/WiFiChallengeLab-docker/zerofile 2>/dev/null || true
sed -i '/bash \/etc\/configureUser.sh/d' ~/.bashrc 2>/dev/null || true
EOF

echo 'bash /etc/configureUser.sh' >> /home/user/.bashrc
if id -u vagrant >/dev/null 2>&1; then
  echo 'bash /etc/configureUser.sh' >> /home/vagrant/.bashrc
fi

# ---------- SSH password auth -------------------------------------------------
sudo sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh 2>/dev/null || sudo systemctl restart sshd 2>/dev/null || true

# ---------- Trust the WiFiChallenge CA (website / captive-portal TLS) ---------
# The lab website and captive portals are served over HTTPS by the AP/Client
# containers with a certificate signed by the WiFiChallenge CA (certs/ca.crt).
# Install it into the host trust store (curl / chromium / GNOME) here, and into
# Firefox via the enterprise policy below, so every profile trusts it without
# launching the browser or editing cert9.db by hand.
if [ -f /var/WiFiChallengeLab-docker/certs/ca.crt ]; then
  run_as_root install -m 0644 /var/WiFiChallengeLab-docker/certs/ca.crt \
    /usr/local/share/ca-certificates/WiFiChallenge-CA.crt
  run_as_root update-ca-certificates || true
fi

# ---------- Firefox ESR policies ---------------------------------------------
# Certificates.Install trusts the WiFiChallenge CA in every Firefox profile
# (present and future) as soon as the browser starts, so the lab HTTPS pages no
# longer show the self-signed warning. Absolute paths are honoured by Firefox
# 65+ (ESR on Debian 12 is 115+); both paths are listed so it works whether the
# CA is read from the system trust dir or straight from the repo.
sudo mkdir -p /usr/lib/firefox-esr/distribution
sudo tee /usr/lib/firefox-esr/distribution/policies.json >/dev/null <<'EOF'
{
  "policies": {
    "Homepage": {
      "URL": "http://127.0.0.1:22900",
      "StartPage": "homepage",
      "Locked": false
    },
    "Certificates": {
      "ImportEnterpriseRoots": true,
      "Install": [
        "/usr/local/share/ca-certificates/WiFiChallenge-CA.crt",
        "/var/WiFiChallengeLab-docker/certs/ca.crt"
      ]
    }
  }
}
EOF

# ---------- docker health watchdog -------------------------------------------
SCRIPT=/usr/local/bin/monitor-health.sh
SERVICE=/etc/systemd/system/monitor-health.service

sudo tee "$SCRIPT" >/dev/null <<'EOF'
#!/bin/bash
while true; do
  for c in $(docker ps --filter "health=unhealthy" --format "{{.Names}}"); do
    sleep 30
    if docker ps --filter "name=$c" --filter "health=unhealthy" --format "{{.Names}}" | grep -qx "$c"; then
      docker restart "$c" || true
    fi
  done
  sleep 30
done
EOF
sudo chmod +x "$SCRIPT"

sudo tee "$SERVICE" >/dev/null <<EOF
[Unit]
Description=Restart unhealthy Docker containers
After=docker.service
[Service]
ExecStart=$SCRIPT
Restart=always
[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now monitor-health.service

# ---------- Network + DNS: consolidate on NetworkManager + systemd-resolved ----
# Goal: identical, reliable DHCP IP + DNS on VirtualBox, VMware, QEMU and Hyper-V.
#
# The generic/debian12 box ships ifupdown + resolvconf + ifplugd bound to eth0,
# and GNOME pulls in NetworkManager on top. That left the wired link "unmanaged"
# in the desktop and (together with installTools.sh) pinned /etc/resolv.conf to
# an immutable 1.1.1.1/8.8.8.8, which breaks DNS on any network that blocks those
# resolvers. We retire the legacy stack and let NetworkManager own every ethernet
# device (name independent, so it behaves the same on every hypervisor) with
# systemd-resolved doing DNS: per-link DHCP servers first, public fallback after.
apt_install network-manager systemd-resolved

# 1) systemd-resolved: prefer the link/DHCP DNS, fall back to public resolvers.
sudo mkdir -p /etc/systemd/resolved.conf.d
sudo tee /etc/systemd/resolved.conf.d/wifichallenge-dns.conf >/dev/null <<'EOF'
[Resolve]
# DNS= is intentionally empty: per-link (DHCP) servers are used first so the lab
# also works on restricted or corporate networks. FallbackDNS covers networks
# that hand out no usable resolver.
FallbackDNS=1.1.1.1 8.8.8.8 9.9.9.9
EOF
sudo systemctl enable systemd-resolved 2>/dev/null || true
sudo systemctl restart systemd-resolved 2>/dev/null || true
# Point glibc at the systemd-resolved stub (the standard, mutable symlink).
if [ -e /run/systemd/resolve/stub-resolv.conf ]; then
  sudo chattr -i /etc/resolv.conf 2>/dev/null || true
  sudo ln -sf /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
fi

# 2) Retire the legacy ifupdown/resolvconf/ifplugd uplink so it cannot fight
#    NetworkManager. Keep loopback only in /etc/network/interfaces; the current
#    DHCP lease stays up until the post-install reboot, so SSH is never dropped.
if [ -f /etc/network/interfaces ]; then
  sudo cp -a /etc/network/interfaces "/etc/network/interfaces.wifichallenge.bak.$(date +%s)" 2>/dev/null || true
  sudo tee /etc/network/interfaces >/dev/null <<'EOF'
# Managed by NetworkManager (WiFiChallengeLab). Loopback only here.
source /etc/network/interfaces.d/*
auto lo
iface lo inet loopback
EOF
fi
sudo systemctl disable --now ifplugd 2>/dev/null || true
sudo systemctl disable --now resolvconf 2>/dev/null || true
apt_purge resolvconf ifplugd

# 3) NetworkManager owns the ethernet uplink and uses systemd-resolved for DNS,
#    but must NEVER touch the lab's simulated radios or container plumbing.
sudo mkdir -p /etc/NetworkManager/conf.d
sudo tee /etc/NetworkManager/conf.d/99-wifichallenge.conf >/dev/null <<'EOF'
[main]
plugins=keyfile
dns=systemd-resolved
[keyfile]
# Leave the mac80211_hwsim Wi-Fi radios and the docker/namespace veth plumbing
# alone; the lab drives those with iw/hostapd/wpa_supplicant, not NetworkManager.
unmanaged-devices=type:wifi;interface-name:veth*;interface-name:vpeer*;interface-name:docker*;interface-name:br-*;interface-name:hwsim*
EOF

# 4) Explicit, name-independent DHCP profile for the NAT uplink (eth0 on the
#    generic box across every provider). An explicit profile guarantees DHCP
#    even if the auto "Wired connection" does not trigger on some hypervisor.
sudo mkdir -p /etc/NetworkManager/system-connections
sudo tee /etc/NetworkManager/system-connections/eth0-nat.nmconnection >/dev/null <<'EOF'
[connection]
id=eth0-nat
type=ethernet
interface-name=eth0
autoconnect=true
autoconnect-priority=100
[ethernet]
[ipv4]
method=auto
[ipv6]
method=ignore
EOF
sudo chmod 600 /etc/NetworkManager/system-connections/eth0-nat.nmconnection

# 5) Optional host-only interface (eth1) so RDP-by-IP works as documented.
#    Provider aware: VirtualBox -> 192.168.56.10, VMware -> 192.168.59.10.
#    never-default keeps internet routing through the NAT uplink (eth0).
HOSTONLY_IP=""
if command -v dmidecode >/dev/null 2>&1; then
  if sudo dmidecode -s system-product-name 2>/dev/null | grep -iq virtualbox; then
    HOSTONLY_IP="192.168.56.10"
  elif sudo dmidecode -s system-product-name 2>/dev/null | grep -iq vmware; then
    HOSTONLY_IP="192.168.59.10"
  fi
fi
if [ -n "$HOSTONLY_IP" ]; then
  sudo tee /etc/NetworkManager/system-connections/eth1-hostonly.nmconnection >/dev/null <<EOF
[connection]
id=eth1-hostonly
type=ethernet
interface-name=eth1
autoconnect=true
autoconnect-priority=50
[ethernet]
[ipv4]
method=manual
address1=${HOSTONLY_IP}/24
never-default=true
may-fail=true
[ipv6]
method=ignore
EOF
  sudo chmod 600 /etc/NetworkManager/system-connections/eth1-hostonly.nmconnection
fi

sudo systemctl enable NetworkManager 2>/dev/null || true

# 6) Disable dnsmasq on the host if present (the lab runs its own inside the AP
#    container network namespace, not on the host).
if service_exists dnsmasq.service; then
  sudo systemctl disable dnsmasq || true
fi

# 7) Boot-time self-heal: if NetworkManager ever fails to bring up a default
#    route on a given hypervisor, escalate to a one-shot DHCP so SSH/RDP and
#    internet always recover (anti-brick safety net for the uplink switch).
sudo tee /usr/local/sbin/ensure-net.sh >/dev/null <<'EOF'
#!/bin/bash
# Give NetworkManager a chance first.
for _ in $(seq 1 30); do
  ip route show default | grep -q . && exit 0
  sleep 2
done
nmcli networking on 2>/dev/null || true
nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="ethernet"{print $1}' | while read -r d; do
  nmcli device connect "$d" 2>/dev/null || true
done
for _ in $(seq 1 10); do
  ip route show default | grep -q . && exit 0
  sleep 2
done
# Last resort: one-shot DHCP on the first ethernet device.
ETH="$(ls /sys/class/net 2>/dev/null | grep -E '^(eth|en)' | head -n1)"
[ -n "$ETH" ] && dhclient -1 "$ETH" 2>/dev/null || true
EOF
sudo chmod +x /usr/local/sbin/ensure-net.sh
sudo tee /etc/systemd/system/ensure-net.service >/dev/null <<'EOF'
[Unit]
Description=WiFiChallengeLab network self-heal (ensure a default route exists)
After=NetworkManager.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/ensure-net.sh
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable ensure-net.service 2>/dev/null || true

# ---------- guest additions ---------------------------------------------------
if command -v dmidecode >/dev/null 2>&1; then
  if dmidecode | grep -iq vmware; then
    apt_install open-vm-tools-desktop
  elif dmidecode | grep -iq virtualbox; then
    apt_install virtualbox-guest-utils virtualbox-guest-x11
  fi
fi
# ---------- sound  ---------------------------------------------------

apt_install alsa-utils

apt_install sox libsox-fmt-all pipewire-audio-client-libraries


# ---------- allow root X11 ----------------------------------------------------
for u in vagrant user; do
  if id -u "$u" >/dev/null 2>&1; then
    if command -v xhost >/dev/null 2>&1; then
      su - "$u" -c 'if [ -n "$DISPLAY" ]; then xhost si:localuser:root; fi' || true
      echo 'if [ -n "$DISPLAY" ] && command -v xhost >/dev/null 2>&1; then xhost si:localuser:root >/dev/null 2>&1; fi' >> "/home/$u/.bashrc"
    fi
  fi
done

# ---------- Autologin with GDM3 on Debian ------------------------------------
USERNAME="user"
GDM_CONF="/etc/gdm3/daemon.conf"
sudo mkdir -p /etc/gdm3
sudo touch "$GDM_CONF"
sudo cp "$GDM_CONF" "$GDM_CONF.bak.$(date +%F-%T)" 2>/dev/null || true

if ! grep -q '^\[daemon\]' "$GDM_CONF"; then
  echo "[daemon]" | sudo tee -a "$GDM_CONF" >/dev/null
fi

sudo awk -v user="$USERNAME" '
BEGIN { insec=0; wrote=0 }
{
  if ($0 ~ /^\[daemon\]/) { print; insec=1; next }
  if (insec && $0 ~ /^\[/) {
    if (!wrote) {
      print "AutomaticLoginEnable=true"
      print "AutomaticLogin=" user
      print "WaylandEnable=false"
      wrote=1
    }
    insec=0
  }
  if (insec) {
    if ($0 ~ /^(#\s*)?AutomaticLoginEnable\s*=/) next
    if ($0 ~ /^(#\s*)?AutomaticLogin\s*=/) next
    if ($0 ~ /^(#\s*)?WaylandEnable\s*=/) next
  }
  print
}
END {
  if (insec && !wrote) {
    print "AutomaticLoginEnable=true"
    print "AutomaticLogin=" user
    print "WaylandEnable=false"
  }
}
' "$GDM_CONF" | sudo tee "$GDM_CONF.tmp" >/dev/null && sudo mv "$GDM_CONF.tmp" "$GDM_CONF"

sudo systemctl enable gdm3 || true
sudo sed -i -E 's/^#?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"

# ---------- isc-dhcp-server common failure fix -------------------------------
# Fixes "isc-dhcp-server.service failed" when INTERFACESv4 is empty or wrong.
if [ -f /etc/default/isc-dhcp-server ]; then
  IFACE=""
  for candidate in wlan70 wlan0 eth0 ens33 enp0s3; do
    if ip link show "$candidate" >/dev/null 2>&1; then
      IFACE="$candidate"
      break
    fi
  done
  if [ -n "$IFACE" ]; then
    sudo sed -i -E "s/^INTERFACESv4=.*/INTERFACESv4=\"$IFACE\"/" /etc/default/isc-dhcp-server || true
    sudo sed -i -E 's/^INTERFACESv6=.*/INTERFACESv6=""/' /etc/default/isc-dhcp-server || true
    sudo systemctl restart isc-dhcp-server 2>/dev/null || true
  fi
fi

# ---------- debloat -----------------------------------------------------------
sudo apt-mark manual wireshark firefox-esr || true

packages=(
  "thunderbird*"
  "libreoffice-*"
  "aisleriot"
  "gnome-mahjongg" "gnome-mines" "gnome-sudoku" "gnome-robots"
  "mahjongg"
  "ace-of-penguins"
  "gbrainy"
  "five-or-more" "four-in-a-row" "iagno" "tali" "swell-foop" "quadrapassel"
  "cheese"
  "shotwell"
  "remmina"
  "totem*"
  "rhythmbox*"
  "transmission-*"
  "yelp" "yelp-xsl"
  "gnome-user-docs"
  "gnome-2048"
  "gnome-chess"
  "gnome-contacts"
  "gnome-klotski"
  "gnome-maps"
  "gnome-music"
  "gnome-nibbles"
  "gnome-taquin"
  "gnome-tetravex"
  "gnome-weather"
  "hitori"
  "hoichess"
  "lightsoff"
  "simple-scan"
  "gnome-sound-recorder"
  "zutty"
)
for pkg in "${packages[@]}"; do
  sudo apt-get -o Dpkg::Use-Pty=0 -y purge "$pkg" </dev/null || true
done

echo 'Install WiFi tools'
sudo bash vagrant/installTools.sh || {
  echo "installTools.sh failed"
  exit 1
}

sudo apt-get -o Dpkg::Use-Pty=0 -y autoremove </dev/null || true
sudo apt-get -o Dpkg::Use-Pty=0 clean </dev/null || true

# Disable plymouth
sudo systemctl disable plymouth-quit-wait.service plymouth-read-write.service 2>/dev/null || true
sudo systemctl mask plymouth-quit-wait.service 2>/dev/null || true
apt_remove plymouth plymouth-theme-*
sudo update-initramfs -u

# initramfs config without duplicates
if [ -f /etc/initramfs-tools/initramfs.conf ]; then
  sudo sed -i -E 's/^MODULES=.*/MODULES=dep/' /etc/initramfs-tools/initramfs.conf || true
  grep -q '^MODULES=' /etc/initramfs-tools/initramfs.conf || echo "MODULES=dep" | sudo tee -a /etc/initramfs-tools/initramfs.conf >/dev/null
  sudo sed -i -E 's/^COMPRESS=.*/COMPRESS=zstd/' /etc/initramfs-tools/initramfs.conf || true
  grep -q '^COMPRESS=' /etc/initramfs-tools/initramfs.conf || echo "COMPRESS=zstd" | sudo tee -a /etc/initramfs-tools/initramfs.conf >/dev/null
  sudo update-initramfs -u
fi

# Disable beep
sudo rmmod pcspkr 2>/dev/null || true
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf >/dev/null
echo "set bell-style none" >> /home/user/.inputrc
sudo chown user:user /home/user/.inputrc

# README
cat >/home/user/README.md <<'EOF'
# WiFiChallengeLab VM
## Overview

WiFiChallenge Lab provides a controlled environment to study, test, and improve WiFi security skills. This VM uses Docker to deploy all required services, offering a simple, portable, and reproducible setup.

## Project Resources

  - Repository: https://github.com/r4ulcl/WiFiChallengeLab-docker
  - Official Website: https://lab.wifichallenge.com

## Learn More - Course and Certification (CWP)

To deepen your knowledge and practice WiFi security professionally, you can enroll in the official course and earn the Certified Wireless Pentester (CWP) certification.
The course provides structured learning, practical challenges, and an internationally recognized certification.

More information available at:
https://academy.wifichallenge.com/courses/certified-wifichallenge-professional-cwp

## Author

- Raúl Calvo Laorden (r4ulcl)
EOF
sudo chown user:user /home/user/README.md

# ---------- cleanup -----------------------------------------------------------
apt_purge gnome-calendar* || true

sudo systemctl stop packagekit 2>/dev/null || true
sudo systemctl disable packagekit 2>/dev/null || true
sudo systemctl mask packagekit 2>/dev/null || true

apt_purge packagekit packagekit-tools packagekit-gtk3-module || true

sudo journalctl --vacuum-time=2d || true
sudo journalctl --vacuum-size=100M || true

sudo rm -rf /var/lib/snapd/cache/* 2>/dev/null || true

rm -f /root/tools/eaphammer/wordlists/rockyou.txt{,.tar.gz} 2>/dev/null || true
sudo apt-get -o Dpkg::Use-Pty=0 autoremove -y </dev/null || true
sudo apt-get -o Dpkg::Use-Pty=0 autoclean -y </dev/null || true
sudo apt-get -o Dpkg::Use-Pty=0 clean -y </dev/null || true
docker system prune -af --volumes || true
sudo apt-get -o Dpkg::Use-Pty=0 autoremove --purge -y </dev/null || true

rm -f /root/resolv.conf.pre-install.* 2>/dev/null || true

sudo rm -r /root/.bash_history /home/user/.bash_history 

echo "Zero fill to shrink image..."
sudo dd if=/dev/zero of=/tmp/zerofile bs=1M 2>/dev/null || true
sudo rm -f /tmp/zerofile

date
