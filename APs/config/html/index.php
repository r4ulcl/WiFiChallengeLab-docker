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
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.8.') !== false) { //only TLS	
		echo "flag{B7OXb7KhFHQCz6WHUMf2}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "CONTOSO\Administrator") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
		echo "flag{RgDOC9yrcRHMAKxgK1PJ}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "admin") {

	
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.6.') !== false) { //only MGT Relay	
		echo "Hello";	
	} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only HIDDEN
		echo "flag{iAYcxpe6N2A98zhglx6E}";
	} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.3.') !== false) { //only WPS
		echo "flag{KD5TaejRFIDgIQwjgUfB}";
	} elseif  (strpos($_SERVER['REMOTE_ADDR'], '192.168.16.') !== false) { //only WPS
		echo "flag{W5ri9DXRJZCTBpFFxXBM}";
	} else {
	    echo "No FLAG, try logging in with another user ;)";

	}
}

#ALL: and strpos($_SERVER['REMOTE_ADDR'], '192.168.X.') !== false to only use users in each network

if ($_SESSION["Username"]  == "CONTOSO\juan.tr") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.5.') !== false) { //only MGT	
		echo "flag{hGDSm8oltjM9q217iJYu}";
		echo "<br><br>";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "test1") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
		echo "flag{feL9kV3oMemAJiEDQLBA}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "test2") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.2.') !== false) { //only PSK	
		echo "flag{feL9kV3oMemAJiEDQLBA}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "free1") {
    if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
		echo "flag{2VphtQyGxsHmRoxGV05a}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "free2") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.10.') !== false) { //only OPN	
		echo "flag{2VphtQyGxsHmRoxGV05a}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

if ($_SESSION["Username"]  == "anon1") {
	# NO AP LOGIN
    echo "flag{b7UP2psiy5LJiShuFZGD}";
}

if ($_SESSION["Username"]  == "administrator") {
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.1.') !== false) { //only WEP	
		echo "flag{g9Ywbxflpye7P0sVAgRQ}";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}

#relay user
if ($_SESSION["Username"]  == "CONTOSOREG\luis.da") { # RELAY
    echo "flag{NBLvyxgwckKnyGup6HNj}";
    echo "<br><br>";
    echo "<br><br>";
}

if ($_SESSION["Username"]  == "CORPO\god") { # RELAY creds stolen in responder in regional network
	if (strpos($_SERVER['REMOTE_ADDR'], '192.168.7.') !== false) { //only WEP	
		echo "flag{3v1GXNkW0dh3T57ppoP1}";
		echo "<br><br>";
		echo "<br><br>";
		echo "<br><br>";
		echo "AP CONFIG:";
		echo "<br><br>";
		echo "
		eap_user_file=/root/mgt/hostapd_wpe.eap_user<br>
		ca_cert=/root/mgt/certs/ca.crt<br>
		server_cert=/root/mgt/certs/server.crt<br>
		private_key=/root/mgt/certs/server.key<br>
		private_key_passwd=whatever<br>
		dh_file=/etc/hostapd-wpe/dh<br>
		<br>
		# 802.11 Options<br>
		ssid=wifi-corp<br>
		channel=6<br>";
	    echo "Certificate Authority:  <a href=\"/.internalCA/\"> http://", $_SERVER['SERVER_ADDR'], "/.internalCA/ </a>";
	} else {
		echo "Your Princess Is in Another Castle!";
	}
}




echo "<br><br>";
echo "<br><br>";
?>

Congratulation! You have logged into password protected page. <a href="logout.php">Click here</a> to Logout.
