#!/bin/bash

docker-compose down

# Remove network namespaces
#sudo ip -all netns delete

# Disable mac80211_hwsim
sudo modprobe mac80211_hwsim -r

sudo systemctl restart systemd-networkd
