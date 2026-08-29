#!/usr/bin/env bash
#
# Prepare a running WiFiChallenge Lab VirtualBox VM for manual export and
# import into AWS EC2. Run this INSIDE the guest, then shut it down and export
# it as an OVA from VirtualBox. No host-side conversion tooling is required.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
SKIP_VBOX_REMOVAL=0
SKIP_RDP_TUNING=0
KEEP_GDM=0
ORIGINAL_ARGS=("$@")

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Run inside the powered-on VirtualBox guest, before manually exporting it as an
OVA for AWS VM Import/Export.

Options:
  --dry-run             Show the actions without changing the guest.
  --skip-vbox-removal   Retain VirtualBox Guest Additions (not recommended).
  --skip-rdp-tuning     Leave the RDP first-connection warm-up out of the image.
  --keep-gdm            Keep the local gdm3 autologin desktop. Costs the first
                        RDP session CPU and RAM, and is useless on EC2.
  -h, --help            Show this help.

The script must run as root. When started as a regular user, it re-runs itself
through sudo. It does not shut down or export the VM.
EOF
}

log() { printf '%s\n' "$*"; }
die() { printf '%s: %s\n' "$SCRIPT_NAME" "$*" >&2; exit 1; }

run() {
  if (( DRY_RUN )); then
    printf '+ '
    printf '%q ' "$@"
    printf '\n'
  else
    "$@"
  fi
}

# Set a key in xrdp.ini's [Globals]. Rewrites the key in place when it is
# already there (commented-out defaults are left alone), otherwise inserts it
# directly under the section header. Callers handle DRY_RUN.
set_xrdp_global() {
  local key="$1" value="$2"
  if grep -qE "^[[:space:]]*${key}=" /etc/xrdp/xrdp.ini; then
    sed -i -E "s/^[[:space:]]*${key}=.*/${key}=${value}/" /etc/xrdp/xrdp.ini
  else
    sed -i "0,/^\[Globals\]/s/^\[Globals\]/[Globals]\n${key}=${value}/" /etc/xrdp/xrdp.ini
  fi
}

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-vbox-removal) SKIP_VBOX_REMOVAL=1 ;;
    --skip-rdp-tuning) SKIP_RDP_TUNING=1 ;;
    --keep-gdm) KEEP_GDM=1 ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1" ;;
  esac
  shift
done

if (( EUID != 0 )); then
  command -v sudo >/dev/null 2>&1 || die "run this script as root"
  exec sudo -- "$0" "${ORIGINAL_ARGS[@]}"
fi

[[ -r /etc/os-release ]] || die "this does not appear to be a Linux guest"
. /etc/os-release
log "Preparing ${PRETTY_NAME:-Linux} for AWS EC2 import..."

if (( ! SKIP_VBOX_REMOVAL )); then
  log 'Removing VirtualBox Guest Additions and VirtualBox-only configuration...'
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl disable vboxadd.service vboxadd-service.service vboxservice.service 2>/dev/null || true
  fi

  # Covers both Debian packages and Guest Additions installed from the Oracle
  # ISO by the Vagrant build.
  if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
    packages=()
    for package in virtualbox-guest-utils virtualbox-guest-x11 virtualbox-guest-dkms virtualbox-guest-source; do
      if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
        packages+=("$package")
      fi
    done
    if (( ${#packages[@]} )); then
      run apt-get purge -y "${packages[@]}"
      run apt-get autoremove -y
    fi
  fi

  shopt -s nullglob
  uninstallers=(/opt/VBoxGuestAdditions-*/uninstall.sh)
  shopt -u nullglob
  for uninstaller in "${uninstallers[@]}"; do
    [[ -x "$uninstaller" ]] || continue
    run "$uninstaller" || true
  done

  run rm -rf -- /opt/VBoxGuestAdditions-* /var/log/vboxadd-* /var/lib/VBoxGuestAdditions
  run rm -f -- /etc/init.d/vboxadd /etc/init.d/vboxadd-service /etc/init.d/vboxadd-x11
  run rm -f -- /etc/modules-load.d/*vbox*.conf /etc/modprobe.d/*vbox*.conf
  run rm -f -- /etc/X11/xorg.conf /etc/X11/xorg.conf.d/*vbox*.conf

  # A vboxsf mount or this lab's static host-only network cannot work in EC2.
  if [[ -f /etc/fstab ]]; then
    run sed -i '\|[[:space:]]vboxsf[[:space:]]|d; \|/media/WiFiWorkshop[[:space:]]|d; \|/media/WiFiChallengeLab[[:space:]]|d' /etc/fstab
  fi
  run rm -f -- /etc/NetworkManager/system-connections/eth1-hostonly.nmconnection
fi

log 'Configuring an EC2-compatible DHCP uplink...'
run install -d -m 700 /etc/NetworkManager/system-connections
if (( DRY_RUN )); then
  log '+ write /etc/NetworkManager/system-connections/eth0-nat.nmconnection (DHCP on eth0)'
else
  cat > /etc/NetworkManager/system-connections/eth0-nat.nmconnection <<'EOF'
[connection]
id=eth0-nat
type=ethernet
interface-name=eth0
autoconnect=true
autoconnect-priority=100

[ipv4]
method=auto

[ipv6]
method=auto
EOF
  chmod 600 /etc/NetworkManager/system-connections/eth0-nat.nmconnection
fi

# ibus-ui-gtk3, from the "ibus" package, pops "Keymap changes do not work in
# Plasma Wayland at present" on sessions that are neither Plasma nor Wayland.
# Debian #1063661 reports it against bookworm's 1.5.27-5, the version this image
# ships. It fires on every RDP login because xrdp's startwm.sh runs
# /etc/X11/Xsession, whose 70im-config_launch starts the input method with its
# own panel before gnome-session takes over. Nothing in the lab needs an input
# method: the us/es layouts configureUser.sh sets are plain xkb sources that
# GNOME switches natively. install.sh does the same at build time; this repeats
# it so images built before that change are also fixed on export.
log 'Removing the IBus input method (spurious Plasma Wayland keymap notification)...'
ibus_packages=()
if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  for package in ibus ibus-gtk3 ibus-gtk4 ibus-data; do
    if dpkg-query -W -f='${db:Status-Status}' "$package" 2>/dev/null | grep -qx installed; then
      ibus_packages+=("$package")
    fi
  done
fi
if (( ${#ibus_packages[@]} )); then
  # gnome-shell only Recommends ibus, so this guard should never fire, but a
  # silently desktop-less image is not a failure mode worth risking on export.
  if apt-get -s purge "${ibus_packages[@]}" 2>/dev/null |
       grep -qE '^(Remv|Purg) (gnome-shell|gnome-session|gnome-core|gdm3|xrdp) '; then
    log 'WARNING: purging IBus would remove the desktop; leaving it installed.'
  else
    run apt-get purge -y "${ibus_packages[@]}"
  fi
fi

# Belt and braces, and the actual fix if the guard above kept the package: stop
# the X session from launching any input method. Per-user files go first so the
# system default written below is what every session ends up reading.
run rm -f -- /home/*/.xinputrc /etc/xdg/autostart/ibus.desktop
run rm -f -- /home/*/.config/autostart/ibus.desktop
if command -v im-config >/dev/null 2>&1; then
  run im-config -n none || true
fi
run pkill -x ibus-daemon || true

# ---------------------------------------------------------------------------
# First-RDP-connection warm-up
# ---------------------------------------------------------------------------
# xrdp builds no session until a client authenticates, so everything the desktop
# needs cold-starts inside that first connection: a fresh Xorg, a full
# gnome-session rendered by llvmpipe, the per-user first-login script, and - on a
# freshly imported AMI - every block of that stack faulted in from S3 by EBS lazy
# loading. Later connections reuse the session and feel instant. The steps below
# move that one-off work into the image and into boot, where nobody is waiting.
if (( ! SKIP_RDP_TUNING )); then
  log 'Tuning the RDP server for a fast first connection...'

  lab_user=''
  if id -u user >/dev/null 2>&1; then
    lab_user=user
  else
    lab_user="$(awk -F: '$3>=1000 && $3<65534 && $1!="nobody" {print $1; exit}' /etc/passwd)"
  fi
  lab_home=''
  if [[ -n "$lab_user" ]]; then
    lab_home="$(getent passwd "$lab_user" | cut -d: -f6)"
  fi

  # 1. Retire the local autologin desktop. install.sh points gdm3 at
  #    AutomaticLogin=user and boots into graphical.target, which is right for a
  #    hypervisor console but wrong for EC2: nobody ever looks at that screen,
  #    and it leaves a second gnome-session for the same user competing with the
  #    RDP one for CPU and for the shared (dbus-user-session) bus. Freeing it
  #    gives the first RDP login the whole machine.
  if (( ! KEEP_GDM )) && command -v systemctl >/dev/null 2>&1; then
    log 'Disabling the console autologin session (EC2 has no local console)...'
    run systemctl set-default multi-user.target
    run systemctl disable gdm3.service 2>/dev/null || true
  fi

  # Unrelated to the console session, so not gated by --keep-gdm:
  # gnome-remote-desktop is a second, redundant RDP stack pulled in by the
  # desktop install. xrdp owns 3389 here.
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl --global disable gnome-remote-desktop.service 2>/dev/null || true
  fi

  # 2. Bake the first-login desktop setup into the image. /etc/configureUser.sh
  #    is triggered from ~/.bashrc, so today it runs apt-get, locale-gen and
  #    ~40 gsettings writes the first time a student opens a terminal inside the
  #    RDP session. Run it now and it is already in the user's dconf database.
  if [[ -n "$lab_user" && -r /etc/configureUser.sh ]]; then
    log "Applying the first-login desktop setup now (user: ${lab_user})..."
    if (( DRY_RUN )); then
      log "+ runuser -u ${lab_user} -- dbus-run-session -- bash /etc/configureUser.sh"
      log '+ remove the /etc/configureUser.sh trigger from the shell profiles'
    elif runuser -u "$lab_user" -- env HOME="$lab_home" USER="$lab_user" \
           LOGNAME="$lab_user" dbus-run-session -- bash /etc/configureUser.sh; then
      # Only drop the trigger once the settings are known to be in place, so a
      # failure here degrades to the current behaviour instead of an unthemed
      # desktop that never self-heals.
      for profile in /home/*/.bashrc /root/.bashrc; do
        [[ -f "$profile" ]] || continue
        sed -i '\|bash /etc/configureUser.sh|d' "$profile"
      done
    else
      log 'WARNING: /etc/configureUser.sh failed; leaving the first-login trigger in place.'
    fi
  fi

  # 3. Build the caches GNOME would otherwise generate during that first login.
  log 'Rebuilding font, icon, MIME, and GSettings caches...'
  if command -v fc-cache >/dev/null 2>&1; then
    run fc-cache -f || true
    if [[ -n "$lab_user" ]]; then
      run runuser -u "$lab_user" -- env HOME="$lab_home" fc-cache -f || true
    fi
  fi
  command -v glib-compile-schemas >/dev/null 2>&1 &&
    run glib-compile-schemas /usr/share/glib-2.0/schemas || true
  command -v update-desktop-database >/dev/null 2>&1 &&
    run update-desktop-database /usr/share/applications || true
  command -v update-mime-database >/dev/null 2>&1 &&
    run update-mime-database /usr/share/mime || true
  if command -v gtk-update-icon-cache >/dev/null 2>&1; then
    for theme in /usr/share/icons/Adwaita /usr/share/icons/hicolor; do
      [[ -d "$theme" ]] && run gtk-update-icon-cache -f -q "$theme" || true
    done
  fi

  # 4. Pre-fault the desktop stack into the page cache on every boot. This is
  #    the part that only an imported AMI needs: its root volume is restored
  #    from a snapshot, so each block is pulled from S3 the first time it is
  #    read, and the first RDP login is what pays for all of them. Reading the
  #    files at idle priority right after boot moves that cost off the
  #    connection path.
  if (( DRY_RUN )); then
    log '+ install /usr/local/sbin/warm-desktop-cache.sh + warm-desktop-cache.service'
  else
    cat > /usr/local/sbin/warm-desktop-cache.sh <<'WARM_EOF'
#!/bin/bash
# Read the xrdp/Xorg/GNOME stack into the page cache so the first RDP session
# after boot starts from RAM. On an EBS volume restored from a snapshot this
# also forces the lazy load from S3 to happen here instead of mid-login.
paths=(
  /usr/bin/Xorg /usr/lib/xorg
  /usr/sbin/xrdp /usr/sbin/xrdp-sesman /usr/lib/xrdp
  /usr/bin/gnome-shell /usr/bin/gnome-session /usr/libexec/gnome-session-binary
  /usr/lib/gnome-shell /usr/share/gnome-shell
  /usr/lib/x86_64-linux-gnu/dri
  /usr/lib/x86_64-linux-gnu/gtk-3.0
  /usr/lib/x86_64-linux-gnu/gjs
  /usr/share/icons/Adwaita
  /usr/share/glib-2.0/schemas
  /usr/share/fonts
  /var/cache/fontconfig
)
shopt -s nullglob
# libLLVM/libgallium are the llvmpipe software renderer: large, and on the
# critical path for every frame GNOME Shell draws without a GPU.
paths+=(
  /usr/lib/x86_64-linux-gnu/mutter-*
  /usr/lib/x86_64-linux-gnu/libLLVM*.so.*
  /usr/lib/x86_64-linux-gnu/libgallium*.so.*
  /usr/lib/x86_64-linux-gnu/libgtk-3.so.*
  /usr/lib/x86_64-linux-gnu/libgdk-3.so.*
  /usr/lib/x86_64-linux-gnu/libmutter-*.so.*
  /usr/lib/x86_64-linux-gnu/libgjs.so.*
  /usr/lib/x86_64-linux-gnu/libgio-2.0.so.*
  /usr/lib/x86_64-linux-gnu/libglib-2.0.so.*
  /usr/lib/firefox-esr
  /home/*/.cache
  /home/*/.config
)
shopt -u nullglob

(( ${#paths[@]} )) || exit 0
find "${paths[@]}" -type f -print0 2>/dev/null | xargs -0 -r cat >/dev/null 2>&1 || true
WARM_EOF
    chmod 0755 /usr/local/sbin/warm-desktop-cache.sh
    cat > /etc/systemd/system/warm-desktop-cache.service <<'UNIT_EOF'
[Unit]
Description=Warm the xrdp/GNOME desktop stack into the page cache
After=multi-user.target

[Service]
# Type=simple so nothing in the boot path waits on it, idle priority so it
# yields to the lab containers and to a student who connects immediately.
Type=simple
Nice=19
IOSchedulingClass=idle
ExecStart=/usr/local/sbin/warm-desktop-cache.sh

[Install]
WantedBy=multi-user.target
UNIT_EOF
  fi
  if command -v systemctl >/dev/null 2>&1; then
    run systemctl daemon-reload
    run systemctl enable warm-desktop-cache.service 2>/dev/null || true
  fi

  # 5. autorun skips the session-type chooser: without it xrdp shows a module
  #    dropdown, and picking anything but Xorg (Xvnc, console) stalls until it
  #    times out, which reads as a slow first connect. max_bpp drops the alpha
  #    byte, which costs bandwidth and compression time on every frame over a
  #    WAN link without adding anything the lab UI uses. installRDP.sh sets the
  #    same depth at build time; this covers images built before that.
  if [[ -f /etc/xrdp/xrdp.ini ]]; then
    if (( DRY_RUN )); then
      log '+ set autorun=Xorg and max_bpp=24 in /etc/xrdp/xrdp.ini'
    else
      set_xrdp_global autorun Xorg
      set_xrdp_global max_bpp 24
    fi
  fi
fi

# VM Import/Export does not support predictable interface names. This gives the
# NetworkManager DHCP profile a stable eth0 target when EC2 presents its NIC.
if [[ -f /etc/default/grub ]] && ! grep -q 'net.ifnames=0' /etc/default/grub; then
  if (( DRY_RUN )); then
    log '+ add net.ifnames=0 biosdevname=0 to GRUB_CMDLINE_LINUX_DEFAULT'
  else
    if grep -q '^GRUB_CMDLINE_LINUX_DEFAULT=' /etc/default/grub; then
      sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 net.ifnames=0 biosdevname=0"/' /etc/default/grub
    else
      printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="net.ifnames=0 biosdevname=0"' >> /etc/default/grub
    fi
  fi
fi

# Nitro EC2 exposes EBS as NVMe and uses ENA networking. The Debian 12 kernel
# already provides these modules; listing them makes them available early in the
# initramfs without replacing the lab's patched kernel.
if [[ -d /etc/initramfs-tools ]]; then
  if (( DRY_RUN )); then
    log '+ ensure nvme, ena, virtio_pci, and virtio_blk are included in initramfs'
  else
    modules_file=/etc/initramfs-tools/modules
    touch "$modules_file"
    for module in nvme ena virtio_pci virtio_blk; do
      grep -qxF "$module" "$modules_file" || printf '%s\n' "$module" >> "$modules_file"
    done
    update-initramfs -u -k all
  fi
fi

if command -v update-grub >/dev/null 2>&1; then
  run update-grub
fi
if command -v systemctl >/dev/null 2>&1; then
  run systemctl enable NetworkManager.service 2>/dev/null || true
  run systemctl enable ssh.service 2>/dev/null || true
fi

missing_drivers=()
for driver in nvme ena; do
  if ! find /lib/modules -type f -name "${driver}.ko*" -print -quit 2>/dev/null | grep -q .; then
    missing_drivers+=("$driver")
  fi
done

if (( ${#missing_drivers[@]} )); then
  log "WARNING: kernel module(s) not found: ${missing_drivers[*]}"
  log 'Do not import to a Nitro instance until the installed kernel has the required AWS drivers.'
else
  log 'AWS Nitro drivers found: ENA and NVMe.'
fi

cat <<'EOF'

Preparation complete.

Next steps:
  1. Shut down cleanly: sudo poweroff
  2. In VirtualBox, export the powered-off VM as an OVA.
  3. Upload that OVA to S3 and import it with: aws ec2 import-image ...

Do not export a saved-state VM. Test the imported AMI in an isolated VPC and
limit its security group to the ports you intentionally need.
EOF
