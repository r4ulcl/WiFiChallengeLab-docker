#!/usr/bin/env bash
#
# Prepare a running WiFiChallenge Lab VirtualBox VM for manual export and
# import into AWS EC2. Run this INSIDE the guest, then shut it down and export
# it as an OVA from VirtualBox. No host-side conversion tooling is required.

set -Eeuo pipefail

SCRIPT_NAME="$(basename "$0")"
DRY_RUN=0
SKIP_VBOX_REMOVAL=0
ORIGINAL_ARGS=("$@")

usage() {
  cat <<EOF
Usage: $SCRIPT_NAME [options]

Run inside the powered-on VirtualBox guest, before manually exporting it as an
OVA for AWS VM Import/Export.

Options:
  --dry-run             Show the actions without changing the guest.
  --skip-vbox-removal   Retain VirtualBox Guest Additions (not recommended).
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

while (( $# )); do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --skip-vbox-removal) SKIP_VBOX_REMOVAL=1 ;;
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

# Debian's older IBus releases show a spurious Plasma Wayland notification on
# login: "Keymap changes do not work in Plasma Wayland". The issue is fixed in
# IBus 1.5.29, but Debian 12 images can still carry an older version. IBus is
# optional for the lab and is not responsible for normal keyboard layouts, so
# remove the affected runtime instead of adding an unstable input-method update
# to an imported EC2 guest. Plasma continues to manage layouts natively.
if command -v dpkg-query >/dev/null 2>&1 && command -v apt-get >/dev/null 2>&1; then
  ibus_version="$(dpkg-query -W -f='${Version}' ibus 2>/dev/null || true)"
  if [[ -n "$ibus_version" ]] && dpkg --compare-versions "$ibus_version" lt 1.5.29~beta1; then
    log "Removing affected IBus runtime (${ibus_version}) to prevent the Plasma Wayland keymap notification..."
    run apt-get purge -y ibus
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
