# install
sudo make -C /lib/modules/$(uname -r)/build  M=$PWD  modules

sudo cp mac80211_hwsim.ko \
     /lib/modules/$(uname -r)/kernel/drivers/net/wireless/
sudo depmod -a

sudo rmmod mac80211_hwsim 
sudo modprobe mac80211_hwsim radios=2 channels=1