#!/bin/bash

#set -euo pipefail

# ---------- helper -----------------------------------------------------------
edit_config_file() {
    local file="$1" setting="$2" value="$3"
    if grep -q "^${setting}" "$file"; then
        sudo sed -i "s|^${setting}.*|${setting} \"${value}\";|" "$file"
    else
        echo "${setting} \"${value}\";" | sudo tee -a "$file" >/dev/null
    fi
}

DEV=False
DEV=True

# ---------- base system ------------------------------------------------------
sudo apt-get update
sudo apt-get full-upgrade -y

# optional housekeeping
sudo apt-get purge -y unattended-upgrades update-manager update-notifier

# Disable daily update check
sudo systemctl disable --now apt-daily.timer apt-daily-upgrade.timer
sudo systemctl mask apt-daily.service apt-daily-upgrade.service

# Fix error black screen on restart
bak="/etc/default/grub.$(date +%F_%H%M%S).bak"
cp /etc/default/grub "$bak"


# Create a clean config
cat | sudo tee /etc/default/grub >/dev/null <<'EOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT_STYLE=menu
GRUB_TIMEOUT=1
GRUB_DISTRIBUTOR=$(lsb_release -i -s 2> /dev/null || echo Debian)
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash"
GRUB_CMDLINE_LINUX=""
EOF

update-grub
update-initramfs -u

sudo apt install lightdm
sudo dpkg-reconfigure lightdm

touch /home/user/.Xauthority
chmod 600 /home/user/.Xauthority
chown user:user /home/user/.Xauthority

sudo apt update
sudo apt install -y $(ubuntu-drivers devices | awk '/recommended/ {print $3}') firmware-misc-nonfree mesa-utils

sudo systemctl disable bettercap

# ---------- user -------------------------------------------------------------
sudo useradd -m -s /bin/bash user
echo "user:user" | sudo chpasswd
# Add the user to the sudo group
sudo usermod -aG sudo user
# Configure sudo to not prompt for a password
echo "user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/user
sudo chmod 0440 /etc/sudoers.d/user

# ---------- polkit tweaks ----------------------------------------------------
# Allow user to scan WiFi
cat <<'EOF' | sudo tee /etc/polkit-1/localauthority/50-local.d/47-allow-wifi-scan.pkla
[Allow Wifi Scan]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.wifi.scan;org.freedesktop.NetworkManager.enable-disable-wifi;org.freedesktop.NetworkManager.settings.modify.own;org.freedesktop.NetworkManager.settings.modify.system;org.freedesktop.NetworkManager.network-control
ResultAny=yes
ResultInactive=yes
ResultActive=yes
EOF

cat <<'EOF' | sudo tee /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla
[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes
EOF

# ---------- Docker -----------------------------------------------------------
# NOTE: apt‑key is deprecated in noble; switch to keyring file               ### 24.04 change
sudo apt-get install -y apt-transport-https ca-certificates curl gpg
sudo install -m 0755 -d /etc/apt/keyrings                                 ### 24.04 change
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg                      ### 24.04 change
sudo chmod a+r /etc/apt/keyrings/docker.gpg                               ### 24.04 change

echo "deb [arch=$(dpkg --print-architecture) \
signed-by=/etc/apt/keyrings/docker.gpg] \
https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list >/dev/null                 ### 24.04 change

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io
sudo apt-get install -y bridge-utils
sudo systemctl restart docker

# ---------- WiFiChallengeLab -------------------------------------------------
cd /var
if [ "$DEV" = "True" ]; then
  git clone -b dev http://10.10.20.10:3005/r4ulcl/WiFiChallengeLab-docker
else
  git clone http://10.10.20.10:3005/r4ulcl/WiFiChallengeLab-docker
fi
cd /var/WiFiChallengeLab-docker

echo 'Install RDP server'; sudo bash Attacker/installRDP.sh
echo 'Install WiFi tools'; sudo bash Attacker/installTools.sh

cd /var/WiFiChallengeLab-docker/nzyme/nzyme-logs/
rm -rf logs/ data/
sudo apt-get install -y p7zip-full
7z x nzyme-logs.7z

cd /var/WiFiChallengeLab-docker/APs/mac80211_hwsim/
sudo bash install.sh

cd /var/WiFiChallengeLab-docker
sudo docker compose -f docker-compose-local.yml build
docker tag wifichallengelab-docker-clients r4ulcl/wifichallengelab-clients
docker tag wifichallengelab-docker-aps r4ulcl/wifichallengelab-aps
docker tag wifichallengelab-docker-nzyme r4ulcl/wifichallengelab-nzyme
docker image rm wifichallengelab-docker-nzyme wifichallengelab-docker-aps wifichallengelab-docker-clients

sudo docker compose -f docker-compose.yml up -d
# sudo docker compose -f docker-compose-minimal.yml up -d

# ---------- flags & helper scripts ------------------------------------------
echo 'flag{2162ae75cdefc5f731dfed4efa8b92743d1fb556}' | sudo tee /root/flag.txt

sudo tee /root/restartWiFi.sh /home/user/restartWiFi.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo docker compose restart aps
sudo docker compose restart clients
EOF
chmod +x /root/restartWiFi.sh /home/user/restartWiFi.sh

sudo tee /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh >/dev/null <<'EOF'
#!/bin/bash
cd /var/WiFiChallengeLab-docker
sudo docker compose pull
sudo docker compose up --detach
EOF
chmod +x /root/updateWiFiChallengeLab.sh /home/user/updateWiFiChallengeLab.sh

# ---------- cgroup memory / swap accounting ---------------------------------
grub_file=/etc/default/grub
params="cgroup_enable=memory swapaccount=1"
if ! grep -q "$params" "$grub_file"; then
  sudo sed -i "/^GRUB_CMDLINE_LINUX=/ s/\"$/ $params\"/" "$grub_file"
  sudo update-grub
fi

# ---------- Wi‑Fi scan powersave tweak --------------------------------------
sudo sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' \
  /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
sudo systemctl restart NetworkManager

# ---------- misc assets ------------------------------------------------------
sudo mkdir -p /opt/background/
sudo cp WiFiChallengeLab.png /opt/background/

sudo apt-get install -y jq
sudo wget -q https://www.nzyme.org/favicon.ico -O /opt/background/nzyme.ico

# nzyme notification loop
sudo tee /var/nzyme-alerts.sh >/dev/null <<'EOF'
#!/bin/bash
PID_FILE=/var/run/nzyme-alerts.pid
if [ -e "$PID_FILE" ] && ps -p "$(cat $PID_FILE)" >/dev/null; then
  echo "Already running"; exit 1
fi
trap "rm -f $PID_FILE; exit" SIGINT SIGTERM
echo $$ >"$PID_FILE"

LOG=/var/WiFiChallengeLab-docker/logsNzyme/alerts.log
GREP="MULTIPLE_SIGNAL_TRACKS|BANDIT_CONTACT|DEAUTH_FLOOD|UNEXPECTED_FINGERPRINT|UNEXPECTED_BSSID|UNEXPECTED_CHANNEL"
LAST=$(grep -E "$GREP" "$LOG" | tail -n1 | jq .message)

while true; do
  NOW=$(grep -E "$GREP" "$LOG" | tail -n1 | jq .message)
  if [ "$NOW" != "$LAST" ]; then
    LAST=$NOW
    notify-send -i /opt/background/nzyme.ico "WIDS Nzyme" "$NOW"
  fi
  sleep 0.1
done
EOF
sudo chown user:user /var/nzyme-alerts.sh
sudo chmod +x /var/nzyme-alerts.sh

echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-user.log 2>&1 &' \
  >> /home/user/.bashrc
echo 'nohup bash /var/nzyme-alerts.sh >/tmp/nzyme-alerts-vagrant.log 2>&1 &' \
  >> /home/vagrant/.bashrc

# ---------- monitor‑mode helper ---------------------------------------------
sudo tee /var/aux.sh >/dev/null <<'EOF'
#!/bin/bash
sudo ip link set wlan60 down
sudo iw wlan60 set type monitor
sudo ip link set wlan60 up
EOF
chmod +x /var/aux.sh

# ---------- first‑login desktop setup ---------------------------------------
cat <<'EOF' | sudo tee /etc/configureUser.sh
# GNOME extensions kept identical to 20.04—still present in 24.04          ### 24.04 change
gnome-extensions enable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-appindicators@ubuntu.com
gnome-extensions enable desktop-icons@csoriano

gsettings set org.gnome.desktop.background picture-uri \
  file:////opt/background/WiFiChallengeLab.png

(crontab -l 2>/dev/null; echo "* * * * * bash /var/aux.sh") | crontab -

if ! command -v gnome-tweaks >/dev/null; then
  sudo apt-get install -y gnome-tweaks
fi


gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"

sudo cp /var/WiFiChallengeLab-docker/certs/ca.crt /usr/local/share/ca-certificates/
sudo update-ca-certificates

if ! command -v firefox >/dev/null; then
  sudo apt-get install -y firefox
fi

firefox &
sleep 10
CA=/var/WiFiChallengeLab-docker/certs/ca.crt
PROFILE_DIR=$(find ~/.mozilla/firefox -maxdepth 1 -type d -name '*.default-release' -print -quit)
if [ -n "$PROFILE_DIR" ]; then
  command -v certutil >/dev/null || sudo apt-get install -y libnss3-tools
  certutil -A -n "WiFiChallenge CA" -t "C,," -d sql:"$PROFILE_DIR" -i "$CA"
fi

mkdir -p ~/.local/share/applications
cp /var/lib/snapd/desktop/applications/firefox_firefox.desktop ~/.local/share/applications/
update-desktop-database ~/.local/share/applications/

sudo rm -f /var/WiFiChallengeLab-docker/zerofile 2>/dev/null
sed -i '/bash \/etc\/configureUser.sh/d' ~/.bashrc
gsettings set org.gnome.shell favorite-apps \
"['firefox_firefox.desktop', 'org.gnome.Nautilus.desktop', 'org.wireshark.Wireshark.desktop', 'org.gnome.Terminal.desktop', 'gnome-control-center.desktop']"

sudo sed -i '/media_WiFiChallenge.*vboxsf/d' /etc/fstab

# Disable black screen
gsettings set org.gnome.desktop.session idle-delay 0


EOF

echo 'bash /etc/configureUser.sh' >> /home/vagrant/.bashrc
echo 'bash /etc/configureUser.sh' >> /home/user/.bashrc

# ---------- SSH password auth (unchanged) -----------------------------------
sudo sed -i -E 's/^#?PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh

# ---------- Firefox policies -------------------------------------------------
sudo mkdir -p /etc/firefox/policies

sudo tee /etc/firefox/policies/policies.json >/dev/null <<'EOF'
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

# ---------- docker health watchdog ------------------------------------------
SCRIPT=/usr/local/bin/monitor-health.sh
SERVICE=/etc/systemd/system/monitor-health.service

sudo tee "$SCRIPT" >/dev/null <<'EOF'
#!/bin/bash
while true; do
  for c in $(docker ps --filter "health=unhealthy" --format "{{.Names}}"); do
    sleep 30
    docker ps --filter "name=$c" --filter "health=unhealthy" | grep -q "$c" && {
      echo "$(date) restarting $c"
      docker restart "$c"
    }
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

# ---------- DNS resolver tweaks ---------------------------------------------
sudo mkdir /etc/systemd/resolved.conf.d/
RESOLV='/etc/systemd/resolved.conf.d/dns_servers.conf'
sudo tee "$RESOLV" >/dev/null <<EOF
[Resolve]
DNS=8.8.8.8 1.1.1.1
EOF
sudo systemctl enable systemd-resolved
sudo systemctl restart systemd-resolved


# ---------- guest additions --------------------------------------------------
if dmidecode | grep -iq vmware; then
  sudo apt-get install -y open-vm-tools-desktop
elif dmidecode | grep -iq virtualbox; then
  sudo apt-get install -y virtualbox-guest-additions-iso virtualbox-guest-x11
fi

#---------- Error wayland vbox --------------------------------------------------
CONFIG_FILE="/etc/gdm3/custom.conf"
BACKUP_FILE="${CONFIG_FILE}.$(date +%Y%m%d%H%M%S).bak"
# Detect VirtualBox
is_vbox=false
if command -v systemd-detect-virt >/dev/null 2>&1; then
  [[ "$(systemd-detect-virt --vm)" == "oracle" ]] && is_vbox=true
fi

if [[ $is_vbox == false && -f /sys/class/dmi/id/product_name ]]; then
  grep -qi "VirtualBox" /sys/class/dmi/id/product_name && is_vbox=true
fi

if $is_vbox; then
  if grep -qE '^WaylandEnable=false' "$CONFIG_FILE"; then
    cp "$CONFIG_FILE" "$BACKUP_FILE"
    sed -i 's/^WaylandEnable=false/#WaylandEnable=false/' "$CONFIG_FILE"
    echo "Commented WaylandEnable=false in $CONFIG_FILE"
  else
    echo "Line already commented or not present, nothing to do"
  fi
fi
# ---------- allow root X11 ---------------------------------------------------
for u in vagrant user; do
  su -c 'xhost si:localuser:root' "$u"
  echo 'xhost si:localuser:root >/dev/null 2>&1' >> "/home/$u/.bashrc"
done
export PATH=$PATH:/sbin

# ---------- debloat  -------------------------
sudo apt-mark manual wireshark firefox

packages=(
  "thunderbird*"
  "libreoffice-*"
  "snapd"
  "aisleriot"
  "gnome-mahjongg" "gnome-mines" "gnome-sudoku" "gnome-todo" "gnome-robots"
  "mahjongg"
  "ace-of-penguins"
  "gnomine"
  "gbrainy"
  "five-or-more" "four-in-a-row" "iagno" "tali" "swell-foop" "quadrapassel"
  "cheese"
  "shotwell"
  "totem*"
  "rhythmbox*"
  "transmission-*"
  "yelp" "yelp-xsl"
  "gnome-user-docs" "ubuntu-docs"
)

for pkg in "${packages[@]}"; do
  echo "Purging $pkg ..."
  if sudo apt-get -y purge "$pkg"; then
    echo "Removed $pkg"
  else
    echo "Could not remove $pkg (not installed or dependency problem)"
  fi
done

# Clean up any orphaned dependencies that are left behind.
sudo apt-get -y autoremove


sudo apt-get -y autoremove
sudo apt-get clean

sudo apt-get -y autoremove --purge ubuntu-web-launchers thunderbird* libreoffice-* snapd \
  aisleriot gnome-{mahjongg,mines,sudoku,todo,robots} \
  mahjongg ace-of-penguins gnomine gbrainy \
  five-or-more four-in-a-row iagno tali swell-foop quadrapassel \
  cheese shotwell totem* rhythmbox* \
  transmission-* \
  yelp yelp-xsl gnome-user-docs ubuntu-docs


# ---------- cleanup ----------------------------------------------------------
# https://forums.virtualbox.org/viewtopic.php?start=30&t=110879
sudo sed -i 's/^#WaylandEnable=false/WaylandEnable=false/' /etc/gdm3/custom.conf
sudo systemctl restart gdm3

# Remove unused programms - (Avahi is for mDNS, Apport is crash reporting, Whoopsie is error reporting.)
sudo apt purge gnome-calendar* -y
sudo dpkg -l | awk '/^rc/ {print $2}' | xargs sudo apt purge -y
sudo journalctl --vacuum-time=2d
sudo journalctl --vacuum-size=100M

# ---------- cleanup ----------------------------------------------------------
sudo apt purge linux-image-5.15.0-153-generic linux-image-5.15.0-91-generic linux-image-generic
sudo rm -rf /var/lib/snapd/cache/*

rm -f /root/tools/eaphammer/wordlists/rockyou.txt{,.tar.gz} || true
sudo apt-get autoremove -y && sudo apt-get autoclean -y && sudo apt-get clean -y
docker system prune -af  --volumes
sudo apt-get autoremove --purge -y

echo "Zero‑fill to shrink image…"
sudo dd if=/dev/zero of=/tmp/zerofile bs=1M || true
sudo rm -f /tmp/zerofile
