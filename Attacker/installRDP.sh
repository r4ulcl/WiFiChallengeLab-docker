#!/bin/bash
set -e

sudo apt-get update

# Debian desktop
# Use task-gnome-desktop for a full GNOME environment or gnome-core for a lighter set
if ! dpkg -s task-gnome-desktop >/dev/null 2>&1 && ! dpkg -s gnome-core >/dev/null 2>&1; then
  sudo apt-get -y install task-gnome-desktop || sudo apt-get -y install gnome-core
fi

sudo apt-get -y install xrdp gnome-shell-extension-prefs

# xrdp tweaks
sudo sed -i 's/^new_cursors=true/new_cursors=false/g' /etc/xrdp/xrdp.ini || true
# Use the systemd unit that runs GNOME on Debian rather than an Ubuntu specific target
sudo sed -i 's/^startwm=.*/startwm=default/g' /etc/xrdp/xrdp.ini || true

{
  echo "resolution=0"
  echo "width=1920"
  echo "height=1080"
} | sudo tee -a /etc/xrdp/xrdp.ini >/dev/null

sudo systemctl enable xrdp
sudo systemctl restart xrdp
