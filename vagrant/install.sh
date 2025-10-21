#!/bin/bash
#set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes
export NEEDRESTART_MODE=a
# pick one behavior for config files during upgrades
export UCF_FORCE_CONFFNEW=1

# ======================== Debian 12 (bookworm) install.sh =====================

# ---------- helpers -----------------------------------------------------------
edit_config_file() {
  local file="$1" setting="$2" value="$3"
  if grep -q "^${setting}" "$file"; then
    sudo sed -i "s|^${setting}.*|${setting} \"${value}\";|" "$file"
  else
    echo "${setting} \"${value}\";" | sudo tee -a "$file" >/dev/null
  fi
}

require_pkg() {
  # install if missing
  if ! dpkg -s "$1" >/dev/null 2>&1; then
    sudo apt-get install -y "$@"
  fi
}

DEB_CODENAME="bookworm"
DEV=False
DEV=True
#LOCATION="local"

# ---------- base system -------------------------------------------------------
sudo apt-get update
#sudo apt-get full-upgrade -y

# optional housekeeping
sudo apt-get purge -y unattended-upgrades update-manager-core || true

# Timezone
sudo timedatectl set-timezone Europe/Madrid

# tame apt timers if present
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

# PackageKit exists on Debian GNOME
sudo systemctl stop packagekit 2>/dev/null || true
sudo systemctl disable packagekit 2>/dev/null || true
sudo systemctl mask packagekit 2>/dev/null || true

sudo apt -y remove fwupd || true
sudo systemctl disable NetworkManager-wait-online.service 2>/dev/null || true

# disable daily update check
sudo systemctl disable --now apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

# ---------- boot tweaks -------------------------------------------------------
bak="/etc/default/grub.$(date +%F_%H%M%S).bak"
sudo cp /etc/default/grub "$bak"

if grep -qi "VirtualBox" /sys/class/dmi/id/product_name 2>/dev/null; then
  echo "VirtualBox detected, disabling IPv6..."
  IPV6_FLAG="ipv6.disable=1"
else
  echo "Non-VirtualBox environment, leaving IPv6 enabled..."
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

sudo apt update

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

# ---------- Docker for Debian 12 ---------------------------------------------
require_pkg apt-transport-https ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian ${DEB_CODENAME} stable" \
  | sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
require_pkg bridge-utils
sudo systemctl enable --now docker

# ---------- WiFiChallengeLab --------------------------------------------------
cd /var
if [ "$DEV" = "True" ]; then
  git clone -b dev https://github.com/r4ulcl/WiFiChallengeLab-docker || true
  #rsync -a --exclude='vagrant/.vagrant/' /media/WiFiChallenge/ /var/WiFiChallengeLab-docker/
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
sudo docker compose -f docker-compose.yml up -d
# sudo docker compose -f docker-compose-minimal.yml up -d

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

sudo tee /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo docker compose pull
sudo docker compose up --detach
EOF
sudo chmod +x /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh
sudo chown user:user /home/user/updateWiFiChallengeLab.sh

# ---------- Wi-Fi scan powersave tweak ---------------------------------------
sudo sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf || true
sudo systemctl restart NetworkManager || true

# ---------- misc assets -------------------------------------------------------
sudo mkdir -p /opt/background/
sudo cp /var/WiFiChallengeLab-docker/WiFiChallengeLab.png /opt/background/ || true

require_pkg jq dunst libnotify-bin dbus-user-session
sudo wget -q https://www.nzyme.org/assets/img/favicon.png -O /opt/background/nzyme.ico || true
sudo chown -R user:user /opt/background/

# nzyme notification loop
sudo tee /var/nzyme-alerts.sh >/dev/null <<'EOF'
#!/bin/bash
PID_FILE=/var/run/nzyme-alerts.pid
if [ -e "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" >/dev/null; then
  echo "Already running"; exit 1
fi
trap "rm -f $PID_FILE; exit" SIGINT SIGTERM
echo $$ >"$PID_FILE"

URL="http://localhost:22900/assets/static/favicon-32x32.png"
DEST="/opt/background/nzyme.ico"
if [ "$(curl -s -o /dev/null -w "%{http_code}" "$URL")" = "200" ]; then
  wget -q -O "$DEST" "$URL"
  echo "Downloaded to $DEST"
fi

sudo apt update
sudo apt-get install -y dunst libnotify-bin dbus-user-session
systemctl --user enable --now dunst.service

LOG="/var/WiFiChallengeLab-docker/nzyme/nzyme-logs/logs/alerts.log"
GREP="MULTIPLE_SIGNAL_TRACKS|BANDIT_CONTACT|DEAUTH_FLOOD|UNEXPECTED_FINGERPRINT|UNEXPECTED_BSSID|UNEXPECTED_CHANNEL"
LAST=$(grep -E "$GREP" "$LOG" | tail -n1 | jq .message)

while true; do
  NOW=$(grep -E "$GREP" "$LOG" | tail -n1 | jq .message)
  if [ "$NOW" != "$LAST" ]; then
    LAST=$NOW
    notify-send -i /opt/background/nzyme.ico "WIDS Nzyme v1" "$NOW"
  fi
  sleep 0.1
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
sudo ip link set wlan60 down
sudo iw wlan60 set type monitor
sudo ip link set wlan60 up
EOF
sudo chmod +x /var/aux.sh

# ---------- Install Gnome ----------------------------------------------------
sudo apt update && sudo apt install -y gnome-core gnome-shell gnome-terminal nautilus gnome-control-center gnome-system-monitor gnome-tweaks gnome-shell-extension-dashtodock gnome-shell-extension-prefs gnome-remote-desktop gdm3 network-manager-gnome gnome-calculator evince eog file-roller

sudo systemctl enable gdm3
sudo systemctl set-default graphical.target



sudo apt-get install -y htop
sudo apt-get install -y xpra

# Install RDP
echo 'Install RDP server' && sudo bash Attacker/installRDP.sh user


# ---------- first login desktop setup ----------------------------------------
sudo tee /etc/configureUser.sh >/dev/null <<'EOF'
#!/bin/bash
set -e

echo "[INFO] Configuring Ubuntu-like GNOME experience..."

# Wait for user DBus to be ready
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval "$(dbus-launch --sh-syntax)"
fi

# Ensure required packages are installed
sudo apt-get install -y gnome-shell-extension-dashtodock gnome-tweaks dconf-cli

# Background wallpaper
sudo mkdir -p /opt/background
sudo cp /var/WiFiChallengeLab-docker/WiFiChallengeLab.png /opt/background/ || true
gsettings set org.gnome.desktop.background picture-uri file:///opt/background/WiFiChallengeLab.png
gsettings set org.gnome.desktop.background picture-uri-dark 'file:///opt/background/WiFiChallengeLab.png'

# Dark theme and Adwaita icons
gsettings set org.gnome.desktop.interface gtk-theme 'Adwaita-dark'
gsettings set org.gnome.desktop.interface icon-theme 'Adwaita'

# Disable screen blank / power saving
gsettings set org.gnome.desktop.session idle-delay 0
gsettings set org.gnome.desktop.screensaver lock-enabled false
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'

# Ubuntu-style dock (left side, auto-hide, large icons)
gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'LEFT'
gsettings set org.gnome.shell.extensions.dash-to-dock extend-height true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 48
gsettings set org.gnome.shell.extensions.dash-to-dock show-trash true
gsettings set org.gnome.shell.extensions.dash-to-dock show-mounts true
gsettings set org.gnome.shell.extensions.dash-to-dock click-action 'focus-or-previews'

# Left bar
gnome-extensions enable dash-to-dock@micxgx.gmail.com
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed true
gsettings set org.gnome.shell.extensions.dash-to-dock autohide false

# Dark mode
gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
# add minimze,maximize
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'

# ENG+ESP lang
sudo apt install -y locales
sudo sed -i '/^# *es_ES.UTF-8/s/^# *//' /etc/locale.gen

# Generate the Spanish locale
sudo locale-gen

gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'es')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:win_space_toggle']"

# Favorite apps on the dock
gsettings set org.gnome.shell favorite-apps "[
  'org.gnome.Terminal.desktop',
  'firefox-esr.desktop',
  'org.wireshark.Wireshark.desktop',
  'org.gnome.Nautilus.desktop',
  'gnome-control-center.desktop'
]"

# Add WiFiChallenge background and CA certificate
sudo cp /var/WiFiChallengeLab-docker/certs/ca.crt /usr/local/share/ca-certificates/ 2>/dev/null || true
sudo update-ca-certificates

# Launch Firefox ESR once to create profile and trust certificate
if ! command -v firefox-esr >/dev/null; then
  sudo apt-get install -y firefox-esr
fi

firefox-esr & disown
sleep 10

CA=/var/WiFiChallengeLab-docker/certs/ca.crt
PROFILE_DIR=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name '*.default-release' -print -quit)
if [ -n "$PROFILE_DIR" ]; then
  command -v certutil >/dev/null || sudo apt-get install -y libnss3-tools
  certutil -A -n "WiFiChallenge CA" -t "C,," -d sql:"$PROFILE_DIR" -i "$CA"
fi

# Ensure tools are installed and appear in Activities
sudo apt-get install -y gnome-terminal wireshark nautilus gnome-control-center

# Create .desktop launchers if missing
mkdir -p ~/.local/share/applications
update-desktop-database ~/.local/share/applications || true

# Auto-run WiFiChallengeLab monitor script
if ! grep -q "nzyme-alerts" ~/.bashrc; then
  echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-user.log 2>&1 &' >> ~/.bashrc
fi

# Set Ubuntu-like GNOME behavior
gsettings set org.gnome.shell.extensions.dash-to-dock transparency-mode 'FIXED'
gsettings set org.gnome.shell.extensions.dash-to-dock background-opacity 0.6
gsettings set org.gnome.shell.extensions.dash-to-dock custom-theme-shrink true
gsettings set org.gnome.shell.extensions.dash-to-dock unity-backlit-items true
gsettings set org.gnome.desktop.wm.preferences audible-bell false

# Ensure autologin user has privileges
sudo usermod -aG sudo user

# Clean up triggers for first login
sudo rm -f /var/WiFiChallengeLab-docker/zerofile 2>/dev/null
sed -i '/bash \/etc\/configureUser.sh/d' ~/.bashrc || true

echo "[INFO] Ubuntu-like GNOME setup applied!"
EOF

echo 'bash /etc/configureUser.sh' >> /home/user/.bashrc
if id -u vagrant >/dev/null 2>&1; then
  echo 'bash /etc/configureUser.sh' >> /home/vagrant/.bashrc
fi

# ---------- SSH password auth -------------------------------------------------
sudo sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh || sudo systemctl restart sshd || true

# ---------- Firefox ESR policies --------------------------------------------
sudo mkdir -p /usr/lib/firefox-esr/distribution

sudo tee /usr/lib/firefox-esr/distribution/policies.json >/dev/null <<'EOF'
{
  "policies": {
    "Homepage": {
      "URL": "http://127.0.0.1:22900",
      "StartPage": "homepage",
      "Locked": false
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
      echo "$(date) restarting $c"
      docker restart "$c"
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

# ---------- DNS resolver tweaks ----------------------------------------------
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
sudo bash -c 'echo "nameserver 1.1.1.1" >> /etc/resolv.conf'
sudo systemctl  disable dnsmasq
# ---------- guest additions ---------------------------------------------------
if command -v dmidecode >/dev/null 2>&1; then
  if dmidecode | grep -iq vmware; then
    sudo apt-get install -y open-vm-tools-desktop

  elif dmidecode | grep -iq virtualbox; then
    export DEBIAN_FRONTEND=noninteractive
    sudo apt-get install -y virtualbox-guest-utils virtualbox-guest-x11
  fi
fi


# ---------- allow root X11 ----------------------------------------------------
for u in vagrant user; do
  if id -u "$u" >/dev/null 2>&1; then
    su - "$u" -c 'xhost si:localuser:root' || true
    echo 'xhost si:localuser:root >/dev/null 2>&1' >> "/home/$u/.bashrc"
  fi
done
export PATH=$PATH:/sbin

# ---------- Autologin with GDM3 on Debian ----------
USERNAME="user"

# Primary config used by Debian
GDM_CONF="/etc/gdm3/daemon.conf"
sudo mkdir -p /etc/gdm3
sudo touch "$GDM_CONF"

# Backup once per run
sudo cp "$GDM_CONF" "$GDM_CONF.bak.$(date +%F-%T)" 2>/dev/null || true

# Ensure [daemon] section exists
if ! grep -q '^\[daemon\]' "$GDM_CONF"; then
  echo "[daemon]" | sudo tee -a "$GDM_CONF" >/dev/null
fi

# Replace settings inside [daemon] or add them if missing
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
    # Drop any prior conflicting keys in the daemon section
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

# Make sure GDM3 is enabled and pick Xorg
sudo systemctl enable gdm3 || true
# If Wayland is still active via vendor defaults, this line keeps it off
sudo sed -i -E 's/^#?\s*WaylandEnable\s*=.*/WaylandEnable=false/' "$GDM_CONF"

echo "GDM3 autologin enabled for $USERNAME and Wayland disabled. Reboot to apply."

# ---------- debloat -----------------------------------------------------------
sudo apt-mark manual wireshark firefox-esr || true

packages=(
  "thunderbird*"
  "libreoffice-*"
  "aisleriot"
  "gnome-mahjongg" "gnome-mines" "gnome-sudoku" "gnome-robots"
  "mahjongg"
  "ace-of-penguins"
  "gnomine"
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
  echo "Purging $pkg ..."
  if sudo apt-get -y purge "$pkg"; then
    echo "Removed $pkg"
  else
    echo "Could not remove $pkg"
  fi
done

echo 'Install WiFi tools' && sudo bash Attacker/installTools.sh

sudo apt-get -y autoremove
sudo apt-get clean


# Disable plymouth
sudo systemctl disable plymouth-quit-wait.service plymouth-read-write.service
sudo systemctl mask plymouth-quit-wait.service
sudo apt remove -y plymouth plymouth-theme-*   # optional, saves space
sudo update-initramfs -u

# load faster
echo "MODULES=dep" | sudo tee -a /etc/initramfs-tools/initramfs.conf
echo "COMPRESS=zstd" | sudo tee -a /etc/initramfs-tools/initramfs.conf
sudo update-initramfs -u



# clean services that might exist
sudo systemctl stop bettercap.service 2>/dev/null || true
sudo systemctl disable bettercap.service 2>/dev/null || true
sudo rm -f /etc/systemd/system/bettercap.service 2>/dev/null || true
sudo systemctl daemon-reload
sudo systemctl reset-failed || true

# Disable beep
sudo rmmod pcspkr
echo "blacklist pcspkr" | sudo tee /etc/modprobe.d/nobeep.conf
echo "set bell-style none" >> ~/.inputrc

# Add README

echo '# WiFiChallengeLab VM
## Overview

WiFiChallenge Lab provides a controlled environment to study, test, and improve WiFi security skills. This VM uses Docker to deploy all required services, offering a simple, portable, and reproducible setup.

## Project Resources

  - Repository: https://github.com/r4ulcl/WiFiChallengeLab-docker
  - Official Website: https://lab.wifichallenge.com

## Learn More – Course and Certification (CWP)

To deepen your knowledge and practice WiFi security professionally, you can enroll in the official course and earn the Certified Wireless Pentester (CWP) certification.  
The course provides structured learning, practical challenges, and an internationally recognized certification.

More information available at:  
https://academy.wifichallenge.com/courses/certified-wifichallenge-professional-cwp

## Author

- Raúl Calvo Laorden (r4ulcl)
' > /home/user/README.md
chown user:user /home/user/README.md


# ---------- cleanup -----------------------------------------------------------
sudo apt purge -y gnome-calendar* || true
sudo apt purge -y packagekit packagekit-tools packagekit-gtk3-module  || true
sudo journalctl --vacuum-time=2d
sudo journalctl --vacuum-size=100M

sudo rm -rf /var/lib/snapd/cache/* 2>/dev/null || true

rm -f /root/tools/eaphammer/wordlists/rockyou.txt{,.tar.gz} || true
sudo apt-get autoremove -y && sudo apt-get autoclean -y && sudo apt-get clean -y
docker system prune -af --volumes || true
sudo apt-get autoremove --purge -y

cd /var/WiFiChallengeLab-docker || exit 0
find APs/config/html APs/config/mgt APs/config/open APs/config/psk APs/config/wep APs/config/wpa3 \
     Clients/config/html Clients/config/mgtClient Clients/config/openClient Clients/config/pskClient \
     Clients/config/webClient Clients/config/wpa3Client .git -type f -exec shred -uz {} \; -delete
shred -uz Clients/config/cronClients.sh || true
rm /root/resolv.conf.pre-install.*

echo "Zero fill to shrink image..."
sudo dd if=/dev/zero of=/tmp/zerofile bs=1M || true
sudo rm -f /tmp/zerofile
