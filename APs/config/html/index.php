<?php session_start(); /* Starts the session */
if(!isset($_SESSION['UserData']['Username'])){
header("location:login.php");
exit;
}
?>

<?php
echo "Welcome ", $_SESSION["Username"];
echo "<br><br>";
echo "<br><br>";

if ($_SESSION["Username"]  == "GLOBAL\GlobalAdmin") {
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only TLS	
		echo "FLAG: WnIlomDsedsOj5I5AQzG0ZoMIhmJIJeejksyma64";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "CONTOSO\Administrator") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only TLS	
		echo "FLAG: aY62tP67g5hK4f";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "admin") {

	
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT Relay	
			echo "Hello";	
	} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only HIDDEN
    		echo "FLAG: IkZ4ZeDqgfQ3eUU";
	} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
    		echo "FLAG: pRH6IlFp2OF49x2";
	} else {
	    echo "No FLAG, try logging in with another user ;)";

	}
}

#ALL: and strpos($_SERVER['REMOTE_ADDR'], '192.168.X.') !== false to only use users in each network

if ($_SESSION["Username"]  == "CONTOSO\juan.tr") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
		echo "FLAG: TY62tPV7Vh1hK1o";
		echo "<br><br>";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "test1") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
		echo "FLAG: uTJTGWAbpnxb6uO";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "test2") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
		echo "FLAG: z39kTesr7hzgh9Y";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "free1") {
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.0.') !== false) { //only OPN	
		echo "FLAG: CNq6gDIqLfjROhN";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "free2") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.0.') !== false) { //only OPN	
		echo "FLAG: Bo8JJqByJ2b6yc4";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "anon1") {
	# NO AP LOGIN
    echo "FLAG: XhAK0YVSIwjeBDf";
}

if ($_SESSION["Username"]  == "administrator") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP	
		echo "FLAG: Ke4kKmkrRc3dV0k";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

#relay user
if ($_SESSION["Username"]  == "CONTOSOREG\luis.da") { # RELAY
    echo "FLAG: F4G6$%2f2g4hs";
    echo "<br><br>";
    echo "<br><br>";
		echo "<br><br>";
		echo "AP CONFIG:";
		echo "<br><br>";
		echo "
		eap_user_file=/root/mgt/hostapd-wpe.eap_user<br>
		ca_cert=/root/mgt/certs/ca.crt<br>
		server_cert=/root/mgt/certs/server.crt<br>
		private_key=/root/mgt/certs/server.key<br>
		private_key_passwd=whatever<br>
		dh_file=/etc/hostapd-wpe/dh<br>
		<br>
		# 802.11 Options<br>
		ssid=wifi-corp<br>
		channel=1<br>";
	    echo "Certificate Authority:  <a href=\"/secretCA/\"> http://", $_SERVER['SERVER_ADDR'], "/secretCA/ </a>";
}

echo "<br><br>";
echo "<br><br>";
?>

Congratulation! You have logged into password protected page. <a href="logout.php">Click here</a> to Logout.
