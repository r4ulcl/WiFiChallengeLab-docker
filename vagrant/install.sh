#!/bin/bash

# update package lists
sudo apt-get update

## Install drivers modprobe 
sudo apt-get install -y linux-generic

# Add SWAP file
# Set the size of the swap file in bytes
swap_size=4G
# Create a new file to be used as a swap file
sudo fallocate -l $swap_size /swapfile
# Set the correct permissions on the file
sudo chmod 600 /swapfile
# Format the file as a swap file
sudo mkswap /swapfile
# Enable the swap file
sudo swapon /swapfile
# Make the change permanent by adding the following line to /etc/fstab
echo "/swapfile none swap sw 0 0" | sudo tee -a /etc/fstab

# Create a sudo user
# Create the user
sudo useradd -m -s /bin/bash user
echo "user:pass" | sudo chpasswd
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

## Install docker-compose
#sudo apt-get install -y docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/1.29.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

## Go to WiFiChallengeFolder (git clone...)
cp -r /media/WiFiChallenge /root/
cd /root/WiFiChallenge

## Install RDP server
echo 'Install RDP server'
sudo bash Attacker/installRDP.sh

## Install hacking WiFi tools
echo 'Install hacking WiFi tools'
sudo bash Attacker/installTools.sh

## Extract nzyme default logs (attacker)
cd /root/WiFiChallenge/nzyme/
rm -r logs/ data/
sudo apt-get install -y p7zip-full
7z x nzyme-logs.7z

## Enable docker
cd /root/WiFiChallenge/
sudo docker-compose -f docker-compose.yml up -d
#sudo docker-compose -f docker-compose-minimal.yml up -d


## remove all non-essential programs in an Ubuntu 20 minimal ISO-based Vagrant VM
# remove all non-essential packages
sudo apt-get --yes remove --purge `dpkg --get-selections | grep -v "^lib" | grep -v "^ubuntu-minimal" | grep -v "^tzdata" | grep -v "^gpgv" | grep -v "^gnupg" | grep -v "^apt" | grep -v "^dirmngr" | awk '{print $1}'`
# Remove games
sudo apt-get --yes purge aisleriot gnome-sudoku mahjongg ace-of-penguins gnomine gbrainy gnome-mines
# Remove libreoffice
sudo apt-get --yes purge libreoffice-core libreoffice-calc libreoffice-draw libreoffice-impress libreoffice-math libreoffice-writer
sudo apt-get --yes purge thunderbird
# Remove transmission and cheese
sudo apt-get --yes purge cheese transmission-*
# autoremove any dependencies that are no longer needed
sudo apt-get --yes autoremove
# clean up the package cache
sudo apt-get clean

sudo apt-get -y autoremove --purge ubuntu-web-launchers landscape-client-ui-install  gnome-games-common libreoffice* empathy transmission-gtk cheese gnome-software-common gnome-software-plugin-flatpak gnome-software-plugin-snap gnome-terminal gnome-orca onboard simple-scan gnome-font-viewer gnome-calculator gnome-clocks gnome-screenshot gnome-system-log gnome-system-monitor gnome-documents gnome-music gnome-video-effects gnome-boxes gnome-dictionary gnome-photos gnome-weather gnome-maps gnome-logs gnome-clocks gnome-characters gnome-calendar aisleriot gnome-sudoku gnome-mines gnome-mahjongg thunderbird

# First FLAG
echo 'flag{JPTEXm5yEaYouyIEFffEvPjil}' | sudo tee /root/flag.txt


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

# Configure GUI when user open terminal first time, then delete
echo '
# Enable dock
gnome-extensions enable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-appindicators@ubuntu.com
gnome-extensions enable desktop-icons@csoriano

# Set background

gsettings set org.gnome.desktop.background picture-uri file:////opt/background/WiFiChallengeLab.png


# Dark theme
# Check if gnome-tweaks is installed
if ! [ -x "$(command -v gnome-tweaks)" ]; then
  sudo apt-get -y  install gnome-tweaks
fi

# Change theme to Adwaita-dark
gsettings set org.gnome.desktop.interface gtk-theme "Adwaita-dark"

# Change icon theme to Adwaita
gsettings set org.gnome.desktop.interface icon-theme "Adwaita"

sudo rm -rf /root/WiFiChallenge/zerofile 2> /dev/null

# Auto delete
sed -i "s/bash \/etc\/configureUser.sh//g" /home/vagrant/.bashrc
' > /etc/configureUser.sh

echo 'bash /etc/configureUser.sh' >> /home/vagrant/.bashrc


# Configure GUI when user open terminal first time, then delete in ubuntu user
echo '
# Enable dock
gnome-extensions enable ubuntu-dock@ubuntu.com
gnome-extensions enable ubuntu-appindicators@ubuntu.com
gnome-extensions enable desktop-icons@csoriano

# Set background

gsettings set org.gnome.desktop.background picture-uri file:////opt/background/WiFiChallengeLab.png


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
' > /etc/configureUseruser.sh

echo 'bash /etc/configureUseruser.sh' >> /home/user/.bashrc


# Enable SSH password login
# Open the SSH server configuration file for editing
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/g' /etc/ssh/sshd_config
# Add the line if it doesn't exist
grep -q "PasswordAuthentication yes" /etc/ssh/sshd_config || echo "PasswordAuthentication yes" | sudo tee -a /etc/ssh/sshd_config > /dev/null
# Restart the SSH server to apply the changes
sudo service ssh restart

# default firefox page
PROFILE_DIR=/home/user/.mozilla/firefox/*.default-*
echo 'user_pref("browser.startup.homepage", "http://127.0.0.1:22900");' >> $PROFILE_DIR/prefs.js
echo 'user_pref("browser.startup.page", 1);' >> $PROFILE_DIR/prefs.js

PROFILE_DIR=/home/vagrant/.mozilla/firefox/*.default-*
echo 'user_pref("browser.startup.homepage", "http://127.0.0.1:22900");' >> $PROFILE_DIR/prefs.js
echo 'user_pref("browser.startup.page", 1);' >> $PROFILE_DIR/prefs.js


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
sudo dd if=/dev/zero of=zerofile bs=1M ; sudo rm -rf /root/WiFiChallenge/zerofile