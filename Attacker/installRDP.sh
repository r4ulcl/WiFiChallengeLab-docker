#!/bin/bash
set -e

TARGET_USER="${1:-}"

export DEBIAN_FRONTEND="noninteractive"

need_cmd() { command -v "$1" >/dev/null 2>&1; }
backup_file() { local f="$1"; if [ -f "$f" ] && [ ! -f "${f}.bak" ]; then cp -a "$f" "${f}.bak"; fi; }
detect_user() {
  if [ -n "$TARGET_USER" ]; then id -u "$TARGET_USER" >/dev/null; echo "$TARGET_USER"; return; fi
  if [ -n "${SUDO_USER:-}" ] && id -u "$SUDO_USER" >/dev/null 2>&1; then echo "$SUDO_USER"; return; fi
  awk -F: '$3>=1000 && $1!="nobody" {print $1}' /etc/passwd | head -n1
}
require_root() { if [ "$(id -u)" -ne 0 ]; then echo "Please run as root" >&2; exit 1; fi; }

require_root
USER_NAME="$(detect_user)"
if [ -z "$USER_NAME" ]; then echo "Could not detect a regular user. Pass the username as the first argument." >&2; exit 1; fi
USER_HOME="$(getent passwd "$USER_NAME" | cut -d: -f6)"

echo "Using target user: $USER_NAME ($USER_HOME)"

echo "Updating apt and installing packages..."
apt-get update -y
apt-get install -y xrdp xorgxrdp gnome-session network-manager

# Groups required for xrdp and Wi-Fi control
adduser xrdp ssl-cert >/dev/null 2>&1 || true
adduser "$USER_NAME" netdev >/dev/null 2>&1 || true

# Xwrapper so remote users can start Xorg
XWRAP="/etc/X11/Xwrapper.config"
if [ -e "$XWRAP" ]; then
  backup_file "$XWRAP"
  if grep -q '^allowed_users=' "$XWRAP"; then
    sed -i 's/^allowed_users=.*/allowed_users=anybody/' "$XWRAP"
  else
    echo "allowed_users=anybody" >> "$XWRAP"
  fi
fi

# startwm.sh fix that solved your black screen
STARTWM="/etc/xrdp/startwm.sh"
backup_file "$STARTWM"
if ! grep -q 'unset DBUS_SESSION_BUS_ADDRESS' "$STARTWM"; then
  sed -i '1i unset DBUS_SESSION_BUS_ADDRESS\nunset XDG_RUNTIME_DIR' "$STARTWM"
fi

# Force GNOME for RDP
XSESSION_FILE="$USER_HOME/.xsession"
if [ ! -f "$XSESSION_FILE" ]; then
  echo "gnome-session" > "$XSESSION_FILE"
  chown "$USER_NAME":"$USER_NAME" "$XSESSION_FILE"
  chmod +x "$XSESSION_FILE"
else
  if ! grep -q 'gnome-session' "$XSESSION_FILE"; then
    echo "gnome-session" >> "$XSESSION_FILE"
  fi
fi

# Precreate .Xauthority to avoid permission oddities
touch "$USER_HOME/.Xauthority"
chown "$USER_NAME":"$USER_NAME" "$USER_HOME/.Xauthority"

# Ensure the Xorg session entry exists for dynamic resize
SESMAN_INI="/etc/xrdp/sesman.ini"
if [ -f "$SESMAN_INI" ]; then
  backup_file "$SESMAN_INI"
  if ! grep -q '^\[Xorg\]' "$SESMAN_INI"; then
    cat >> "$SESMAN_INI" <<'EOF'

[Xorg]
param=Xorg
param=-config
param=xrdp/xorg.conf
param=-noreset
param=-nolisten
param=tcp
EOF
  fi
fi

# PolicyKit rule to allow Wi-Fi scans and control inside xrdp sessions
# Grants to users in netdev or sudo group. Adjust groups if you prefer tighter control.
PK_RULE="/etc/polkit-1/rules.d/49-allow-wifi-control.rules"
cat > "$PK_RULE" <<'EOF'
polkit.addRule(function(action, subject) {
  var acts = [
    "org.freedesktop.NetworkManager.wifi.scan",
    "org.freedesktop.NetworkManager.enable-disable-wifi",
    "org.freedesktop.NetworkManager.settings.modify.own",
    "org.freedesktop.NetworkManager.settings.modify.system",
    "org.freedesktop.NetworkManager.network-control",
    "org.freedesktop.NetworkManager.sleep-wake"
  ];
  if (acts.indexOf(action.id) >= 0) {
    if (subject.isInGroup("netdev") || subject.isInGroup("sudo")) {
      return polkit.Result.YES;
    }
  }
});
EOF
chmod 0644 "$PK_RULE"

# Restart services
systemctl enable --now NetworkManager
systemctl enable --now xrdp
systemctl restart xrdp || true

# Polkit is activated by D-Bus. Restart if unit exists, otherwise D-Bus reload will pick up rules.
if systemctl list-unit-files | grep -q '^polkit.*service'; then
  systemctl restart polkit || true
fi

# Optional firewall open
if need_cmd ufw; then ufw allow 3389/tcp || true; fi
