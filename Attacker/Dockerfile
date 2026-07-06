# WiFiChallengeLab - Attacker (headless, docker-exec access)
#
# Docker build of the WiFiChallenge attacker machine: the SAME offensive Wi-Fi
# toolset as the lab VM, but WITHOUT any GUI, RDP or SSH. The container has no
# sshd and no desktop; it just stays alive so you attach to it directly with
# `docker exec`:
#
#     docker compose -f docker-compose-attacker.yml up -d --build
#     docker compose -f docker-compose-attacker.yml exec attacker bash
#   or, without compose:
#     docker build -t wifichallengelab-attacker Attacker/
#     docker run -d --name attacker --privileged --network host \
#                -v /lib/modules:/lib/modules -v /usr/src:/usr/src \
#                wifichallengelab-attacker
#     docker exec -it attacker bash
#
# Kali is the base because the toolset (eaphammer, hostapd-wpe, mdk3, bettercap,
# asleap, the Realtek Alfa DKMS drivers, ...) ships as Kali packages.
#
# This image is meant to be used ALWAYS, not only against the lab. Run it
# privileged with host networking and it drives real USB Wi-Fi adapters too: with
# `--network host` the host's wlanX interfaces are visible inside the container
# (no USB pass-through needed for normal monitor mode / injection), and mounting
# /lib/modules + /usr/src lets the bundled DKMS drivers build against the host
# kernel for adapters the host doesn't already support.
# SECURITY: privileged + host networking can transmit on any radio it sees. Only
# attack networks you own or are authorized to test.
FROM kalilinux/kali-rolling

LABEL org.opencontainers.image.title="WiFiChallengeLab Attacker" \
      org.opencontainers.image.description="Headless (no GUI/RDP/SSH, docker-exec) WiFi attacker toolbox with Alfa adapter drivers" \
      org.opencontainers.image.source="https://github.com/r4ulcl/WiFiChallengeLab-docker"

ENV DEBIAN_FRONTEND=noninteractive \
    DEBCONF_NONINTERACTIVE_SEEN=true \
    DEBCONF_NOWARNINGS=yes \
    DEBIAN_PRIORITY=critical \
    NEEDRESTART_MODE=a \
    UCF_FORCE_CONFFNEW=1 \
    APT_LISTCHANGES_FRONTEND=none \
    PIP_BREAK_SYSTEM_PACKAGES=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

# --- base utilities the install scripts assume are present --------------------
# tini = PID 1 that reaps the processes spawned via `docker exec`. No openssh
# here: access is docker-exec only (no SSH, no GUI, no RDP).
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      tini sudo ca-certificates git wget curl kmod procps iproute2 iw usbutils \
      rfkill pciutils nano \
 && rm -rf /var/lib/apt/lists/*

# --- lab "user" account -------------------------------------------------------
# installTools.sh writes to /home/user and runs `chown user:user`, so the user
# must exist before it runs. user/user with passwordless sudo, matching the VM.
RUN useradd -m -s /bin/bash user \
 && echo 'user:user' | chpasswd \
 && usermod -aG sudo user \
 && echo 'user ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/zzz-user \
 && chmod 0440 /etc/sudoers.d/zzz-user

# --- offensive Wi-Fi toolset (the same installer the lab VM uses) -------------
# Heavy layer: aircrack-ng, eaphammer, hostapd-wpe/mana, airgeddon, wifite2,
# wifiphisher, bettercap, hashcat, john, wpa_sycophant, mdk4, reaver, ...
COPY installTools.sh /root/installTools.sh
RUN bash /root/installTools.sh

# --- Alfa Network USB adapter drivers + firmware ------------------------------
COPY installAlfa.sh /root/installAlfa.sh
RUN bash /root/installAlfa.sh

# --- shrink the (already large) image -----------------------------------------
RUN apt-get autoremove -y || true; apt-get autoclean || true; apt-get clean || true; \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root

# Enter the running container with:  docker exec -it <container> bash
# tini stays PID 1 and reaps zombies; `sleep infinity` keeps the container up
# so it can be attached to at any time.
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["sleep", "infinity"]
