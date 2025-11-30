#!/bin/bash

#Load variables
set -a
source /root/wlan_config_clients


function retry { 
    $1 && echo "success" || (echo "fail" && retry $1) 
}

#40-59 skip OPN
killall dhclien-wifichallenge 2> /dev/nill &
for N in `seq 40 46`; do
	timeout 5s dhclien-wifichallenge wlan$N 2> /dev/nill &
done
for N in `seq 50 59`; do
	timeout 5s dhclien-wifichallenge wlan$N 2> /dev/nill &
done

# Start Apache in client for Client isolation test
service apache2 start > /root/logs/apache2.log 2>&1 &

sleep 10

# DHCP
while :
do
	killall dhclien-wifichallenge 2> /dev/nill &
	for N in `seq 40 46`; do
		timeout 5s dhclien-wifichallenge wlan$N 2> /dev/nill &
	done
	for N in `seq 50 59`; do
		timeout 5s dhclien-wifichallenge wlan$N 2> /dev/nill &
	done
    wait $!
	sleep 60
done &
# Normal clients curls
while :
do
	# MGT MSCHAP
	curl -s "http://$MAC_MGT_MSCHAP.1/login.php" --interface $WLAN_MGT_MSCHAP --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$IDENTITY_MGT_MSCHAP" \
		--data-urlencode "Password=$PASS_MGT_MSCHAP_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userjuan -b /tmp/userjuan &

	# MGT GTC
	curl -s "http://$MAC_MGT_GTC.1/login.php" --interface $WLAN_MGT_GTC --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$IDENTITY_MGT_GTC" \
		--data-urlencode "Password=$PASS_MGT_GTC_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userAdmin -b /tmp/userAdmin &

	# MGT Relay
	curl -s "http://$IP_MGTRELAY.1/login.php" --interface $WLAN_MGT_RELAY --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$IDENTITY_MGT_RELAY" \
		--data-urlencode "Password=$PASS_MGT_RELAY_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userluis -b /tmp/userluis &

	# MGT TLS
	curl -s "http://$IP_MGT_TLS.1/login.php" --interface $WLAN_TLS --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$IDENTITY_MGT_TLS" \
		--data-urlencode "Password=$PASS_MGT_TLS_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userGlobal -b /tmp/userGlobal &

	# MGT TLS PHISHING
	curl -s "http://$IP_MGT_TLS.1/login.php" --interface $WLAN_TLS_PHISHING --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$IDENTITY_MGT_PHISHING" \
		--data-urlencode "Password=$PASS_MGT_PHISHING_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userPhishing -b /tmp/userPhishing &

	# WPA PSK (login only if redirect)
	STATUS=`curl -o /dev/null -w '%{http_code}\n' -s "http://$IP_PSK.1/lab.php" -c /tmp/userTest1 -b /tmp/userTest1`
	if [ "$STATUS" -eq 302 ] ; then
		curl -s "http://$IP_PSK.1/login.php" --interface $WLAN_WPA_PSK --compressed \
			-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
			--data-urlencode "Username=$USER_PSK1" \
			--data-urlencode "Password=$PASS_PSK1_CLEAR" \
			--data-urlencode "Submit=Login" \
			-c /tmp/userTest1 -b /tmp/userTest1 &
	fi

	STATUS=`curl -o /dev/null -w '%{http_code}\n' -s "http://$IP_PSK.1/lab.php" -c /tmp/userTest2 -b /tmp/userTest2`
	if [ "$STATUS" -eq 302 ] ; then
		curl -s "http://$IP_PSK.1/login.php" --interface $WLAN_WPA_PSK2 --compressed \
			-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
			--data-urlencode "Username=$USER_PSK2" \
			--data-urlencode "Password=$PASS_PSK2_CLEAR" \
			--data-urlencode "Submit=Login" \
			-c /tmp/userTest2 -b /tmp/userTest2 &
	fi

	# PSK NOAP
	curl -s "http://$WLAN_PSK_NOAP.1/login.php" --interface $WLAN_PSK_NOAP --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=anon1" \
		--data-urlencode "Password=$PASS_PSK_NOAP_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userAnon1 -b /tmp/userAnon1 &

	curl -s "http://$WLAN_PSK_NOAP2.1/login.php" --interface $WLAN_PSK_NOAP2 --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$USER_PSK_NOAP" \
		--data-urlencode "Password=$PASS_PSK_NOAP_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userAnon11 -b /tmp/userAnon11 &

	# OPEN (kept literal because you have no variables defined)
	curl -s "http://$IP_OPN.1/login.php" --interface $WLAN_OPN1 --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$USER_WEB_OPN1" \
		--data-urlencode "Password=$PASS_WEB_OPN1_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userFree1 -b /tmp/userFree1 &

	curl -s "http://$IP_OPN.1/login.php" --interface $WLAN_OPN2 --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$USER_WEB_OPN2" \
		--data-urlencode "Password=$PASS_WEB_OPN2_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userFree2 -b /tmp/userFree2 &

	curl -s "http://$IP_OPN.1/login.php" --interface $WLAN_OPN3 --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$USER_WEB_OPN3" \
		--data-urlencode "Password=$PASS_WEB_OPN3_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userFree3 -b /tmp/userFree3 &

	# WPA3 Downgrade
	curl -s "http://$IP_DOWNGRADE.1/login.php" --interface $WLAN_DOWNGRADE --compressed \
		-H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' \
		--data-urlencode "Username=$USER_WEB_DOWNGRADE" \
		--data-urlencode "Password=$PASS_WEB_DOWNGRADE_CLEAR" \
		--data-urlencode "Submit=Login" \
		-c /tmp/userManager1 -b /tmp/userManager1 &

	wait $!
	sleep 10
done &

# Phishing 
while :
do
	timeout -k 1 5s dhclien-wifichallenge -v $WLAN_TLS_PHISHING 2> /tmp/dhclien-wifichallenge
	SERVER=`grep -E -o "from (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" /tmp/dhclien-wifichallenge | awk '{print $2}' | head -n 1`

	if [ -n "$SERVER" ]; then
		URL=`curl -L -s -o /dev/null -w %{url_effective} "http://$SERVER/" -c /tmp/userTLSPhishing -b /tmp/userTLSPhishing`
		curl -L -s "$URL" -H 'Content-Type: application/x-www-form-urlencoded' \
			--data-urlencode "username=$IDENTITY_MGT_PHISHING_DOMAIN\\$IDENTITY_MGT_PHISHING_USER" \
			--data-urlencode "password=$PASS_MGT_PHISHING_CLEAR" \
			-c /tmp/userTLSPhishing -b /tmp/userTLSPhishing > /dev/null
	fi

	sleep 1
done &

# Responder
while :
do
	echo loop
	# TODO Responder client connect
	#dhclien-wifichallenge -r $WLAN_TLS_PHISHING 2> /tmp/dhclien-wifichallenge
	timeout -k 1 5s dhclien-wifichallenge -v $WLAN_TLS_PHISHING 2> /tmp/dhclien-wifichallenge-Responder
	SERVER=`grep -E -o "from (25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)" /tmp/dhclien-wifichallenge-Responder | awk '{print $2}' | head -n 1`
	# Responder ""vuln"" - 20 seconds because the SMB takes aprox 10 seconds in respond "Authentication error"
	# In background to be sure
	echo $SERVER
    if [ -n "$SERVER" ]; then
		echo lock

        # Acquire lock and run smbmap. This blocks if another smbmap is running.
        (
            # open fd 9 for lockfile and acquire exclusive lock (blocks until free)
            flock 9
			echo flock
			
			# run smbmap under cpulimit and timeout (background)
			timeout -k 1 10s cpulimit -l 30 -f -- /usr/bin/smbmap -d "$IDENTITY_MGT_PHISHING_DOMAIN" -u "$IDENTITY_MGT_PHISHING_USER" -p "$PASS_MGT_PHISHING_CLEAR" -H "$SERVER" >/dev/null 2>&1 &

			sleep 0.5
            # run smbmap under cpulimit and timeout (foreground)
            timeout -k 1 20s cpulimit -l 30 -f -- /usr/bin/smbmap -d "$IDENTITY_MGT_PHISHING_DOMAIN" -u "IDENTITY_MGT_PHISHING_USER" -p "$PASS_MGT_PHISHING_CLEAR" -H "$SERVER" >/dev/null 2>&1
        ) 9>/var/lock/smbmap.lock

    else
        sleep 1
    fi
done &

# WEP traffic
while :
do
	#Infine traffic WEP
	dhclien-wifichallenge $WLAN_WEP -v
	ping $IP_WEP.1 -s 1000 -f & 
	ping $IP_WEP.1 -s 1000 -f
done &

# Infinite wait
LAST=$!
wait $LAST


#curl "$URL" -X POST -H 'Content-Type: application/x-www-form-urlencoded' --data-raw 'username=user1&password=pass2'
