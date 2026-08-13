#!/bin/sh
# Replace environment variables

echo Updating nzyme.conf using .env

echo $DATABASE_URL

# Create data_directory if not present
mkdir /usr/share/nzyme 2> /dev/null

# If EXTERNAL_URL is unset or points at localhost, derive it from the host's
# reachable IP so the Nzyme web UI works from other computers, not just the VM.
# (nzyme runs with network_mode: host, so "hostname -I" lists the host's IPs.)
case "${EXTERNAL_URL:-}" in
  ""|*localhost*|*127.0.0.1*)
    ALL_IPS="$(hostname -I 2>/dev/null)"
    HOST_IP=""
    # Prefer a 192.168.x host-only/LAN address (reachable from other machines).
    for ip in $ALL_IPS; do
      case "$ip" in 192.168.*) HOST_IP="$ip"; break ;; esac
    done
    # Else the first IPv4 that is not Vagrant NAT, docker or lab-internal.
    if [ -z "$HOST_IP" ]; then
      for ip in $ALL_IPS; do
        case "$ip" in
          *:*) continue ;;                                   # skip IPv6
          10.0.2.*|169.254.*|172.1[6-9].*|172.2[0-9].*|172.3[01].*|10.200.*|127.*) continue ;;
        esac
        HOST_IP="$ip"; break
      done
    fi
    if [ -n "$HOST_IP" ]; then
      EXTERNAL_URL="http://${HOST_IP}:22900"
      echo "nzyme: external URL auto-set to ${EXTERNAL_URL}"
    fi
    ;;
esac
export EXTERNAL_URL

envsubst < /etc/nzyme/nzyme.conf.tmp > /etc/nzyme/nzyme.conf

#/bin/sh /usr/share/nzyme/bin/nzyme
# Run the standard container command
exec "$@"
