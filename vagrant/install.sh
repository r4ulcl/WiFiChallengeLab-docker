#!/bin/bash
#set -euo pipefail

DEV=${1:-false}
LOCATION=${2:-remote}

export DEBIAN_FRONTEND=noninteractive
export DEBCONF_NONINTERACTIVE_SEEN=true
export DEBCONF_NOWARNINGS=yes
export NEEDRESTART_MODE=a
export UCF_FORCE_CONFFNEW=1

# Fix for Debian 12 python packaging guardrails when scripts use "pip install" globally
# Best practice is venv or pipx, but this prevents "externally-managed-environment" hard failures.
export PIP_BREAK_SYSTEM_PACKAGES=1
export PIP_DISABLE_PIP_VERSION_CHECK=1

DEB_CODENAME="bookworm"

date

# ---------- helpers -----------------------------------------------------------
apt_update() {
  sudo apt-get -o Dpkg::Use-Pty=0 update -y </dev/null
}

apt_install() {
  sudo apt-get -o Dpkg::Use-Pty=0 install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confnew" \
    "$@" </dev/null
}

apt_remove() {
  sudo apt-get -o Dpkg::Use-Pty=0 remove -y "$@" </dev/null || true
}

apt_purge() {
  sudo apt-get -o Dpkg::Use-Pty=0 purge -y "$@" </dev/null || true
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

# tame apt timers if present
sudo systemctl stop apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl disable apt-daily.timer apt-daily-upgrade.timer 2>/dev/null || true
sudo systemctl mask apt-daily.service apt-daily-upgrade.service 2>/dev/null || true

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

sudo tee /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo docker compose pull
sudo docker compose up --detach
EOF
sudo chmod +x /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh
sudo chown user:user /home/user/updateWiFiChallengeLab.sh

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
sudo ip link set wlan60 down || exit 0
sudo iw wlan60 set type monitor || exit 0
sudo ip link set wlan60 up || exit 0
EOF
sudo chmod +x /var/aux.sh

# ---------- Install GNOME -----------------------------------------------------
apt_update
apt_install gnome-core gnome-shell gnome-terminal nautilus gnome-control-center gnome-system-monitor \
  gnome-tweaks gnome-shell-extension-dashtodock gnome-shell-extension-prefs gnome-remote-desktop \
  gdm3 network-manager-gnome gnome-calculator evince eog file-roller

sudo systemctl enable gdm3 || true
sudo systemctl set-default graphical.target || true

apt_install htop xpra tmux

# Install RDP
echo 'Install RDP server'
sudo bash Attacker/installRDP.sh user

# ---------- first login desktop setup ----------------------------------------
sudo tee /etc/configureUser.sh >/dev/null <<'EOF'
#!/bin/bash
set -e

if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
  eval "$(dbus-launch --sh-syntax)"
fi

sudo apt-get -o Dpkg::Use-Pty=0 install -y \
  -o Dpkg::Options::="--force-confdef" \
  -o Dpkg::Options::="--force-confnew" \
  gnome-shell-extension-dashtodock gnome-tweaks dconf-cli locales libnss3-tools firefox-esr \
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

sudo cp /var/WiFiChallengeLab-docker/certs/ca.crt /usr/local/share/ca-certificates/ 2>/dev/null || true
sudo update-ca-certificates || true

firefox-esr & disown || true
sleep 10

CA=/var/WiFiChallengeLab-docker/certs/ca.crt
PROFILE_DIR=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name '*.default-release' -print -quit 2>/dev/null || true)
if [ -n "$PROFILE_DIR" ] && [ -f "$CA" ]; then
  command -v certutil >/dev/null 2>&1 || sudo apt-get -o Dpkg::Use-Pty=0 install -y libnss3-tools </dev/null || true
  certutil -A -n "WiFiChallenge CA" -t "C,," -d sql:"$PROFILE_DIR" -i "$CA" 2>/dev/null || true
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

# ---------- Firefox ESR policies ---------------------------------------------
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

# ---------- DNS resolver tweaks ----------------------------------------------
if systemctl is-active systemd-resolved >/dev/null 2>&1; then
  sudo mkdir -p /etc/systemd/resolved.conf.d
  sudo tee /etc/systemd/resolved.conf.d/dns.conf >/dev/null <<'EOF'
[Resolve]
DNS=8.8.8.8 1.1.1.1
FallbackDNS=9.9.9.9
EOF
  sudo systemctl restart systemd-resolved || true
else
  sudo bash -c 'printf "nameserver 8.8.8.8\nnameserver 1.1.1.1\n" > /etc/resolv.conf'
fi

if service_exists dnsmasq.service; then
  sudo systemctl disable dnsmasq || true
fi

# ---------- guest additions ---------------------------------------------------
if command -v dmidecode >/dev/null 2>&1; then
  if dmidecode | grep -iq vmware; then
    apt_install open-vm-tools-desktop
  elif dmidecode | grep -iq virtualbox; then
    apt_install virtualbox-guest-utils virtualbox-guest-x11
  fi
fi

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
  for candidate in wlan60 wlan0 eth0 ens33 enp0s3; do
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
sudo bash Attacker/installTools.sh

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

echo "Zero fill to shrink image..."
sudo dd if=/dev/zero of=/tmp/zerofile bs=1M 2>/dev/null || true
sudo rm -f /tmp/zerofile

date