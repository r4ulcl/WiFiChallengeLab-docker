obj-m := mac80211_hwsim.o

all:   ; $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules
clean: ; $(MAKE) -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean