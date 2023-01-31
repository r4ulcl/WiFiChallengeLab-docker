#!/bin/bash

# Install RDP
sudo apt-get update
sudo apt-get -y install ubuntu-desktop xrdp
sudo apt-get -y install gnome-shell-extension-prefs

sudo sed -i 's/^new_cursors=true/new_cursors=false/g' /etc/xrdp/xrdp.ini
sudo sed -i 's/^startwm=startxfce4/startwm=startubuntu/g' /etc/xrdp/xrdp.ini

echo "resolution=0" >> /etc/xrdp/xrdp.ini
echo "width=1920" >> /etc/xrdp/xrdp.ini
echo "height=1080" >> /etc/xrdp/xrdp.ini

#gnome-extensions enable $(gnome-extensions list --enabled --extension-id | tr '\n' ' ')
#gnome-shell-extension-prefs

sudo systemctl enable xrdp
sudo systemctl restart xrdp
