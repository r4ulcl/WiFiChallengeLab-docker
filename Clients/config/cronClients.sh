#!/bin/bash

#NOP vwifi-client 192.168.190.2 & # ADD to CRON

while :
do
	date

	# Verify IP correct
	#VAR=`ip -br -4 a sh | grep enp0s3 | awk '{print $3}'`
	#if [[ ${VAR} != "192.168.190.16/24" ]] ; then
	#	ip addr add 192.168.190.16/24 dev enp0s3
	#fi


	for N in `seq 20 32`; do
		dhclient wlan$N 2> /dev/nill &
	done

	# Start Apache in client for Client isolation test
	service apache2 start


	sleep 60

	for N in `seq 20 32`; do
		dhclient wlan$N 2> /dev/nill &
	done

	sleep 10

	# MGT
	curl -s 'http://192.168.5.1/login.php' --interface wlan20 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=CONTOSO%5Cjuan.tr&Password=Secret%21&Submit=Login' --cookie-jar /tmp/userjuan &
	curl -s 'http://192.168.5.1/login.php' --interface wlan21 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=CONTOSO%5CAdministrator&Password=SuperSecure%40%21%40&Submit=Login' --cookie-jar /tmp/userAdmin &

	# MGT Relay
	curl -s 'http://192.168.6.1/login.php' --interface wlan30 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=CONTOSOREG%5Cluis.da&Password=u89gh68!6fcv56ed&Submit=Login' --cookie-jar /tmp/userluis  &

	# MGT TLS
	curl -s 'http://192.168.7.1/login.php' --interface wlan22 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=GLOBAL%5CGlobalAdmin&Password=SuperSuperSecure%40%21%40&Submit=Login' --cookie-jar /tmp/userGlobal  &

	# PSK, only login if cookies error
	STATUS=`curl -o /dev/null -w '%{http_code}\n' -s 'http://192.168.2.1/lab.php' -c /tmp/userTest1 -b /tmp/userTest1`
	if [ "$STATUS" -ne 200 ] ; then
		curl -s 'http://192.168.2.1/login.php' --interface wlan23 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=test1&Password=OYfDcUNQu9PCojb&Submit=Login' --cookie-jar /tmp/userTest1
	fi

	STATUS=`curl -o /dev/null -w '%{http_code}\n' -s 'http://192.168.2.1/lab.php' -c /tmp/userTest2 -b /tmp/userTest2`
	if [ "$STATUS" -ne 200 ] ; then
		curl -s 'http://192.168.2.1/login.php' --interface wlan24 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=test2&Password=2q60joygCBJQuFo&Submit=Login' --cookie-jar /tmp/userTest2
	fi

	# PSK NOAPP
	curl -s 'http://10.10.1.1/login.php' --interface wlan25 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=anon1&Password=CRgwj5fZTo1cO6Y&Submit=Login' --cookie-jar /tmp/userAnon1 &
	curl -s 'http://10.10.1.1/login.php' --interface wlan26 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=anon1&Password=CRgwj5fZTo1cO6Y&Submit=Login' --cookie-jar /tmp/userAnon11 &

	# OPEN
	curl -s 'http://192.168.0.1/login.php' --interface wlan27 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=free1&Password=Jyl1iq8UajZ1fEK&Submit=Login' --cookie-jar /tmp/userFree1 &
	curl -s 'http://192.168.0.1/login.php' --interface wlan28 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=free2&Password=5LqwwccmTg6C39y&Submit=Login' --cookie-jar /tmp/userFree2 &
	curl -s 'http://192.168.0.1/login.php' --interface wlan29 --compressed -H 'Content-Type: application/x-www-form-urlencoded' -H 'Connection: keep-alive' -H 'Upgrade-Insecure-Requests: 1' --data-raw 'Username=free1&Password=Jyl1iq8UajZ1fEK&Submit=Login' --cookie-jar /tmp/userFree11 &

	sleep 60

done
