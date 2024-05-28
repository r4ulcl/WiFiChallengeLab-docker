#!/bin/bash

# update package lists
sudo apt-get update

## Install drivers modprobe 
sudo apt-get install -y linux-generic

# Create a sudo user
# Create the user
sudo useradd -m -s /bin/bash user
echo "user:user" | sudo chpasswd
# Add the user to the sudo group
sudo usermod -aG sudo user
# Configure sudo to not prompt for a password
echo "user ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/user
sudo chmod 0440 /etc/sudoers.d/user

# Allow user to scan WiFi
echo '[Allow Wifi Scan]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.wifi.scan;org.freedesktop.NetworkManager.enable-disable-wifi;org.freedesktop.NetworkManager.settings.modify.own;org.freedesktop.NetworkManager.settings.modify.system;org.freedesktop.NetworkManager.network-control
ResultAny=yes
ResultInactive=yes
ResultActive=yes' >> /etc/polkit-1/localauthority/50-local.d/47-allow-wifi-scan.pkla

echo '[Allow Colord all Users]
Identity=unix-user:*
Action=org.freedesktop.color-manager.create-device;org.freedesktop.color-manager.create-profile;org.freedesktop.color-manager.delete-device;org.freedesktop.color-manager.delete-profile;org.freedesktop.color-manager.modify-device;org.freedesktop.color-manager.modify-profile
ResultAny=no
ResultInactive=no
ResultActive=yes' > /etc/polkit-1/localauthority/50-local.d/45-allow-colord.pkla


## Install Docker
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo apt-key fingerprint 0EBFCD88
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Fix DNS error Docker
sudo apt-get install bridge-utils -y
sudo service docker restart

## Go to WiFiChallengeFolder (git clone...)
cp -r /media/WiFiChallenge /var/
cd /var/WiFiChallenge
shred -vzn 3 /var/WiFiChallenge/.git
# No need
shred -vzn 3 /var/WiFiChallenge/APs
shred -vzn 3 /var/WiFiChallenge/Clients

find /var/WiFiChallenge/APs -type f -exec shred -zvu -n 5 {} \;
find /var/WiFiChallenge/Clients -type f -exec shred -zvu -n 5 {} \;
rm -r /var/WiFiChallenge/Clients /var/WiFiChallenge/APs

## Install RDP server
echo 'Install RDP server'
sudo bash Attacker/installRDP.sh

## Install hacking WiFi tools
echo 'Install hacking WiFi tools'
sudo bash Attacker/installTools.sh

## Extract nzyme default logs (attacker)
cd /var/WiFiChallenge/nzyme/
rm -r logs/ data/
sudo apt-get install -y p7zip-full
7z x nzyme-logs.7z

## Enable docker
cd /var/WiFiChallenge/
sudo docker compose -f docker-compose.yml up -d
#sudo docker compose -f docker-compose-minimal.yml up -d


## remove all non-essential programs in an Ubuntu 20 minimal ISO-based Vagrant VM
# remove all non-essential packages
sudo apt-get --yes remove --purge `dpkg --get-selections | grep -v "^lib" | grep -v "^ubuntu-minimal" | grep -v "^tzdata" | grep -v "^gpgv" | grep -v "^gnupg" | grep -v "^apt" | grep -v "^dirmngr" | awk '{print $1}'`
# Remove games
sudo apt-get --yes purge aisleriot gnome-sudoku mahjongg ace-of-penguins gnomine gbrainy gnome-mines
# Remove libreoffice
sudo apt-get --yes purge libreoffice-core libreoffice-calc libreoffice-draw libreoffice-impress libreoffice-math libreoffice-writer
sudo apt-get --yes purge thunderbird snapd
# Remove transmission and cheese
sudo apt-get --yes purge cheese transmission-* gnome-mahjongg
# autoremove any dependencies that are no longer needed
sudo apt-get --yes autoremove
# clean up the package cache
sudo apt-get clean

sudo apt-get -y autoremove --purge ubuntu-web-launchers landscape-client-ui-install  gnome-games-common libreoffice* empathy transmission-gtk cheese gnome-software-common gnome-software-plugin-flatpak gnome-software-plugin-snap gnome-terminal gnome-orca onboard simple-scan gnome-font-viewer gnome-calculator gnome-clocks gnome-screenshot gnome-system-log gnome-system-monitor gnome-documents gnome-music gnome-video-effects gnome-boxes gnome-dictionary gnome-photos gnome-weather gnome-maps gnome-logs gnome-clocks gnome-characters gnome-calendar aisleriot gnome-sudoku gnome-mines gnome-mahjongg thunderbird

# First FLAG
echo 'flag{JPTEXm5yEaYouyIEFffEvPjil}' | sudo tee /root/flag.txt

echo '#!/bin/bash
cd /var/WiFiChallenge

sudo docker compose restart aps
sudo docker compose restart clients' | sudo tee /root/restartWiFi.sh  /home/user/restartWiFi.sh
chmod +x /root/restartWiFi.sh  /home/user/restartWiFi.sh

echo '#!/bin/bash
#Update images from AP and clients
cd /var/WiFiChallenge
sudo docker compose pull
sudo docker compose up --detach
' | sudo tee /root/updateWiFiChallengeLab.sh  /home/user/updateWiFiChallengeLab.sh
chmod +x /root/updateWiFiChallengeLab.sh  /home/user/updateWiFiChallengeLab.sh


#Fix password on wifi scan
# Change the configuration file
sudo sed -i 's/wifi.powersave = 3/wifi.powersave = 2/' /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf
# Restart the network manager
sudo service network-manager restart
# Confirm the changes have been made
echo "The system policy has been updated and the network manager has been restarted. Wi-Fi scans should now be allowed."

#Copy script
sudo mkdir /opt/background/
sudo cp WiFiChallengeLab.png /opt/background/WiFiChallengeLab.png

# nzyme alerts
sudo apt-get install -y jq
# nzyme icon for alerts
sudo wget https://www.nzyme.org/favicon.ico -O /opt/background/nzyme.ico

echo '#!/bin/bash

#check if running
PID_FILE=/var/run/nzyme-alerts.pid

if [ -e "${PID_FILE}" ]; then
    PID=$(cat "${PID_FILE}")
    if ps -p "${PID}" > /dev/null; then
        echo "Error: Script is already running with PID ${PID}."
        exit 1
    else
        echo "Warning: PID file exists but process is not running. Deleting PID file."
        rm "${PID_FILE}"
    fi
fi

# Register a signal trap to remove the PID file if the script is terminated
trap "rm ${PID_FILE}; exit 0" SIGINT SIGTERM SIGHUP

echo $$ > "${PID_FILE}"
# Loop
GREP_STRING="MULTIPLE_SIGNAL_TRACKS|BANDIT_CONTACT|DEAUTH_FLOOD|UNEXPECTED_FINGERPRINT|UNEXPECTED_BSSID|UNEXPECTED_CHANNEL"
ALERT1=`cat /var/WiFiChallenge/logsNzyme/alerts.log  | grep -E "$GREP_STRING" | tail -n 1 | jq .message`
while true ; do
  ALERT2=`cat /var/WiFiChallenge/logsNzyme/alerts.log  | grep -E "$GREP_STRING" | tail -n 1 | jq .message`
  if [ "$ALERT1" != "$ALERT2" ] ; then
    ALERT1=$ALERT2
    notify-send -i /opt/background/nzyme.ico "WIDS Nzyme" "$ALERT2"
  fi
  sleep 0.1
done
' > /var/nzyme-alerts.sh

sudo chown user:user /var/nzyme-alerts.sh
sudo chmod +x /var/nzyme-alerts.sh

echo 'nohup bash /var/nzyme-alerts.sh > /tmp/nzyme-alerts-user.log 2>&1 &' >> /home/user/.bashrc
echo 'nohup bash /var/nzyme-alerts.sh > /tmp/nzyme-alerts-vagrant.log 2>&1 &' >> /home/vagrant/.bashrc


echo '#!/bin/bash
#Script to set nzyme interface in monitor mode always
sudo ip link set wlan60 down 
sudo iw wlan60 set type monitor
sudo ip link set wlan60 up' > /var/aux.sh
chmod +x /var/aux.sh

# Configure GUI when user open terminal first time, then delete
echo '#!/bin/bash
# Enable dock
gnome-extensions enable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-appindicators@ubuntu.com
gnome-extensions enable desktop-icons@csoriano

# Set background
gsettings set org.gnome.desktop.background picture-uri file:////opt/background/WiFiChallengeLab.png

# Cron to monitor mode to nzyme
(crontab -l ; echo "* * * * * bash /var/aux.sh") | crontab -


# Dark theme
# Check if gnome-tweaks is installed
if ! [ -x "$(command -v gnome-tweaks)" ]; then
  sudo apt-get -y  install gnome-tweaks
fi

# Change theme to Adwaita-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

# Change icon theme to Adwaita
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"

sudo rm -rf /var/WiFiChallenge/zerofile 2> /dev/null

# Auto delete
sed -i "s/bash \/etc\/configureUser.sh//g" /home/vagrant/.bashrc
' > /etc/configureUser.sh

echo 'bash /etc/configureUser.sh' >> /home/vagrant/.bashrc


# Configure GUI when user open terminal first time, then delete in ubuntu user
sudo tee /etc/configureUseruser.sh > /dev/null <<EOF
# Enable dock
gnome-extensions enable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-appindicators@ubuntu.com
gnome-extensions enable desktop-icons@csoriano

# Set background
gsettings set org.gnome.desktop.background picture-uri file:////opt/background/WiFiChallengeLab.png

# Cron to monitor mode to nzyme
(crontab -l ; echo "* * * * * /var/aux.sh") | crontab -

# Dark theme
# Check if gnome-tweaks is installed
if ! [ -x "$(command -v gnome-tweaks)" ]; then
  sudo apt-get -y  install gnome-tweaks
fi

# Change theme to Adwaita-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

# Change icon theme to Adwaita
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"

# Auto delete
sed -i "s/bash \/etc\/configureUseruser.sh//g" /home/user/.bashrc

# Add Terminal to favorites
gsettings set org.gnome.shell favorite-apps "$(gsettings get org.gnome.shell favorite-apps | sed s/.$//), 'wireshark.desktop', 'org.gnome.Terminal.desktop']"

# Remove fstab info in VBox
sudo sed -i "/$(echo 'media_WiFiChallenge /media/WiFiChallenge vboxsf uid=1000,gid=1000,_netdev 0 0' | sudo sed -e 's/[\/&]/\\&/g')/d" /etc/fstab


EOF
#' > 

echo 'bash /etc/configureUseruser.sh' >> /home/user/.bashrc


# Enable SSH password login
# Open the SSH server configuration file for editing
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# Add the line if it doesn't exist
grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
# Restart the SSH server to apply the changes
sudo service ssh restart

firefox_dir="/usr/lib/firefox"

# Create a new file in the Firefox installation directory
sudo tee $firefox_dir/distribution/policies.json > /dev/null <<EOF
{
    "policies": {
        "Homepage": {
            "URL": "http://127.0.0.1:22900"
        },
        "Auth": {
            "Login": {
                "nzyme - WiFi Defense System": {
                    "username": "admin",
                    "password": "admin"
                }
            }
        }
    }
}
EOF


# Disable systemd-resolved
sudo sed -i 's/^DNSStubListener=yes/DNSStubListener=no/g' /etc/systemd/resolved.conf
sudo systemctl stop systemd-resolved.service
sudo systemctl disable systemd-resolved.service
# Configure DNS servers
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf >/dev/null
echo "nameserver 8.8.4.4" | sudo tee -a /etc/resolv.conf >/dev/null
# Restart networking service
sudo systemctl restart networking.service

# Install guest additions
# Check if system is running on VMware
if [[ $(dmidecode | grep -i vmware) ]]; then
    echo "Installing open-vm-tools-desktop for VMware"
    sudo apt-get update
    sudo apt-get install -y open-vm-tools-desktop
# Check if system is running on VirtualBox
elif [[ $(dmidecode | grep -i virtualbox) ]]; then
    echo "Installing VirtualBox Guest Additions for VirtualBox"
    sudo apt-get update
    sudo apt-get install -y virtualbox-guest-additions-iso
    sudo apt-get install -y virtualbox-guest-x11 
else
    echo "This script only supports VMware and VirtualBox virtual machines."
fi


# Root acces GUI
su -c 'xhost si:localuser:root' vagrant
su vagrant -c 'xhost +SI:localuser:root'
echo 'xhost si:localuser:root > /dev/null 2>&1' >> /home/vagrant/.bashrc

su -c 'xhost si:localuser:root' user
su user -c 'xhost +SI:localuser:root'
echo 'xhost si:localuser:root > /dev/null 2>&1' >> /home/user/.bashrc
export PATH=$PATH:/sbin

# Make VM smallest posible
rm -rf /root/tools/eaphammer/wordlists/rockyou.txt /root/tools/eaphammer/wordlists/rockyou.txt.tar.gz
sudo apt-get -y autoremove
sudo apt-get -y autoclean
sudo apt-get -y clean

docker system prune -a -f

echo "Starting dd, this may take a while"
sudo dd if=/dev/zero of=/tmp/zerofile bs=1M ; sudo rm -rf /tmp/zerofile
sudo rm -rf /tmp/zerofile