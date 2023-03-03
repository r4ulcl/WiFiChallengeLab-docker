while :
do
	dnsmasq
    sleep 10
done & 

LAST=$!
wait $LAST