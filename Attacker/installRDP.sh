#!/bin/bash
set -e

export DEBIAN_FRONTEND="noninteractive"

# Make sure required GNOME packages are installed
#sudo apt update
sudo apt install -y gnome-remote-desktop

# Enable RDP
gsettings set org.gnome.desktop.remote-desktop.rdp enable true
gsettings set org.gnome.desktop.remote-desktop.rdp view-only false

systemctl --user restart gnome-remote-desktop.service

grdctl rdp set-credentials user user


# Restart GNOME remote desktop service
systemctl --user restart gnome-remote-desktop.service
