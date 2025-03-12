#!/bin/sh
# Replace environment variables

echo Updating nzyme.conf using .env

echo $DATABASE_URL

# Load variables 
if [ -e "/root/wlan_config_aps" ]; then
    source /root/wlan_config_aps
fi

# Create data_directory if not present
mkdir /usr/share/nzyme 2> /dev/null

envsubst < /etc/nzyme/nzyme.conf.tmp > /etc/nzyme/nzyme.conf

#/bin/sh /usr/share/nzyme/bin/nzyme
# Run the standard container command
exec "$@"
