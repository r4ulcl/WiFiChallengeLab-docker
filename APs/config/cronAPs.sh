while :
do
	# Respawn only if dead; a bare dnsmasq each loop failed to bind UDP/67
	pgrep -x dnsmasq >/dev/null || dnsmasq
	sleep 10
done &

LAST=$!
wait $LAST
